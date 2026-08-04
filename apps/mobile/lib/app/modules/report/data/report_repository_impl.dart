import 'dart:convert';

import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entity/category_form_schema_entity.dart';
import '../domain/entity/report_input.dart';
import '../domain/repository/report_repository.dart';
import 'report_queue_tasks.dart';

class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl(this._apiClient, this._queue, {SharedPreferences? prefs})
      : _injectedPrefs = prefs;

  static const _formsCacheKey = 'category_forms_cache_v1';

  final ApiClient _apiClient;
  final OfflineQueueService _queue;
  final SharedPreferences? _injectedPrefs;

  Future<SharedPreferences> get _prefs async =>
      _injectedPrefs ?? await SharedPreferences.getInstance();

  @override
  Future<Either<Failure, SubmitOutcome>> submit(ReportInput input) async {
    try {
      final response = await _apiClient.post('/app-reports', input.toSubmitBody());
      final reportId = response['reportId'] as int;
      // The report never waits for an image (decision 123): photos ride the
      // queue in the background, chained upload → attach per photo.
      for (final photo in input.photos) {
        await _queue.enqueue(ReportQueueTasks.mediaUpload, {
          'reportId': reportId,
          'clientKey': input.clientKey,
          ...photo.toJson(),
        });
      }
      // Fire-and-forget: kick the chain now, the periodic flush self-heals.
      // ignore: unawaited_futures
      _queue.flush();
      return Right(SubmitOutcome.online(reportId));
    } on Failure catch (failure) {
      // The API judged and refused (validation, legal gate 451): a queued
      // retry would fail identically — surface it, never enqueue.
      return Left(failure);
    } catch (_) {
      // Transport failure — the offline promise of decision 28: the whole
      // draft (photos included) waits for connectivity under the SAME
      // clientKey, so an eventual double-send is a 200 replay (137).
      await _queue.enqueue(ReportQueueTasks.submit, input.toJson());
      return const Right(SubmitOutcome.queued());
    }
  }

  @override
  Future<Either<Failure, List<CategoryFormSchemaEntity>>> getCategoryForms() async {
    try {
      final response = await _apiClient.get('/app-reports/category-forms');
      final forms = (response['forms'] as List<dynamic>)
          .map((f) => CategoryFormSchemaEntity.fromJson((f as Map).cast<String, dynamic>()))
          .toList();
      await (await _prefs).setString(
        _formsCacheKey,
        jsonEncode(forms.map((f) => f.toJson()).toList()),
      );
      return Right(forms);
    } on Failure catch (failure) {
      return Left(failure);
    } catch (_) {
      // Offline: the cached catalog keeps the dynamic form rendering
      // (decision 47 — the server re-validates on submit anyway).
      final cached = (await _prefs).getString(_formsCacheKey);
      if (cached == null) {
        return const Left(Failure(message: 'No connection', code: 'OFFLINE'));
      }
      return Right(
        (jsonDecode(cached) as List<dynamic>)
            .map((f) => CategoryFormSchemaEntity.fromJson((f as Map).cast<String, dynamic>()))
            .toList(),
      );
    }
  }
}
