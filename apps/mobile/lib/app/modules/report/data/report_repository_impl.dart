import 'dart:convert';

import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entity/category_form_schema_entity.dart';
import '../domain/entity/feed_item_entity.dart';
import '../domain/entity/report_input.dart';
import '../domain/entity/report_view_entity.dart';
import '../domain/gateway/location_gateway.dart';
import '../domain/repository/report_repository.dart';
import 'my_reports_store.dart';
import 'report_queue_tasks.dart';

class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl(this._apiClient, this._queue, this._myReports,
      {SharedPreferences? prefs})
      : _injectedPrefs = prefs;

  static const _formsCacheKey = 'category_forms_cache_v1';

  final ApiClient _apiClient;
  final OfflineQueueService _queue;
  final MyReportsStore _myReports;
  final SharedPreferences? _injectedPrefs;

  Future<SharedPreferences> get _prefs async =>
      _injectedPrefs ?? await SharedPreferences.getInstance();

  @override
  Future<Either<Failure, SubmitOutcome>> submit(ReportInput input) async {
    try {
      final response = await _apiClient.post('/app-reports', input.toSubmitBody());
      final reportId = response['reportId'] as int;
      // Bearer ownership (decision 134): the clientKey is what lets this
      // device read/edit its own report later.
      await _myReports.save(reportId, input.clientKey);
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

  @override
  Future<Either<Failure, FeedPageEntity>> listNearby(
    GeoPoint position,
    int page,
    FeedOrder order,
  ) async {
    try {
      final response = await _apiClient.get(
        '/app-feed?lat=${position.lat}&lng=${position.lng}&page=$page&order=${order.name}',
      );
      return Right(FeedPageEntity.fromJson(response));
    } on Failure catch (failure) {
      return Left(failure);
    } catch (_) {
      return const Left(Failure(message: 'No connection', code: 'OFFLINE'));
    }
  }

  @override
  Future<Either<Failure, ReportViewEntity>> getReport(int reportId) async {
    try {
      final clientKey = await _myReports.clientKeyOf(reportId);
      final response = await _apiClient.get(
        '/app-reports/$reportId',
        headers: clientKey == null ? null : {'x-client-key': clientKey},
      );
      return Right(ReportViewEntity.fromJson(response));
    } on Failure catch (failure) {
      return Left(failure);
    } catch (_) {
      return const Left(Failure(message: 'No connection', code: 'OFFLINE'));
    }
  }

  @override
  Future<Either<Failure, void>> resolve(int reportId) async {
    try {
      final clientKey = await _myReports.clientKeyOf(reportId);
      await _apiClient.post(
        '/app-reports/$reportId/resolve',
        const {},
        headers: clientKey == null ? null : {'x-client-key': clientKey},
      );
      return const Right(null);
    } on Failure catch (failure) {
      // The API judged (404 non-owner, 422 already resolved): a queued
      // retry would fail identically — surface it, never enqueue (same
      // rule as submit's rejection path).
      return Left(failure);
    } catch (_) {
      // Transport failure — the close survives offline exactly like a
      // report submission does (decisions 28/179).
      await _queue.enqueue(ReportQueueTasks.resolve, {'reportId': reportId});
      // ignore: unawaited_futures
      _queue.flush();
      return const Right(null);
    }
  }
}
