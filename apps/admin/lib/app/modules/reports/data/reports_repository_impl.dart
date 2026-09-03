import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../domain/entity/chat_evidence_entities.dart';
import '../domain/entity/report_entities.dart';
import '../domain/repository/reports_repository.dart';

class ReportsRepositoryImpl implements ReportsRepository {
  ReportsRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Right(await run());
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, ReportPageEntity>> search(
    ReportFiltersEntity filters,
    int page,
    int pageSize,
  ) =>
      _guard(() async {
        // Path + query built by Uri so every value is encoded once.
        final uri = Uri(
          path: '/api/reports',
          queryParameters: {
            'page': '$page',
            'pageSize': '$pageSize',
            ...filters.toQueryParameters(),
          },
        );
        return ReportPageEntity.fromJson(await _apiClient.get(uri.toString()));
      });

  @override
  Future<Either<Failure, ReportPanelDetailEntity>> getDetail(int reportId) => _guard(
      () async => ReportPanelDetailEntity.fromJson(await _apiClient.get('/api/reports/$reportId')));

  @override
  Future<Either<Failure, ReportExactPositionEntity>> getExactPosition(int reportId) =>
      _guard(() async => ReportExactPositionEntity.fromJson(
          await _apiClient.get('/api/reports/$reportId/position')));

  // The four freeze calls mirror `case_freeze_repository_impl.dart` line
  // by line (decision 165): modules never import each other, and
  // duplicating four one-liners is the accepted cost.
  @override
  Future<Either<Failure, ReportFreezeStateEntity>> getFreezeState(int reportId) => _guard(
      () async => ReportFreezeStateEntity.fromJson(await _apiClient.get('/api/case-freeze/$reportId')));

  @override
  Future<Either<Failure, void>> freeze(int reportId, String reason) =>
      _guard(() => _apiClient.post('/api/case-freeze/$reportId/freeze', {'reason': reason}));

  @override
  Future<Either<Failure, void>> requestUnfreeze(int reportId, String reason) => _guard(
      () => _apiClient.post('/api/case-freeze/$reportId/unfreeze-request', {'reason': reason}));

  @override
  Future<Either<Failure, void>> approveUnfreeze(int reportId) =>
      _guard(() => _apiClient.post('/api/case-freeze/$reportId/unfreeze-approve', {}));

  /// `{reasonCode, note?}` — the note travels only when given, so the
  /// API's optional field stays absent rather than an empty string (163).
  Map<String, dynamic> _reasonBody(String reasonCode, String? note) => {
        'reasonCode': reasonCode,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      };

  @override
  Future<Either<Failure, void>> hide(int reportId, String reasonCode, String? note) =>
      _guard(() => _apiClient.post('/api/reports/$reportId/hide', _reasonBody(reasonCode, note)));

  @override
  Future<Either<Failure, void>> unhide(int reportId, String reasonCode, String? note) => _guard(
      () => _apiClient.post('/api/reports/$reportId/unhide', _reasonBody(reasonCode, note)));

  // Media block/unblock live on `/api/media` (media-admin routes) under the
  // same `reports` UPDATE grant (165).
  @override
  Future<Either<Failure, void>> blockMedia(String publicId, String reasonCode, String? note) =>
      _guard(() => _apiClient.post('/api/media/$publicId/block', _reasonBody(reasonCode, note)));

  @override
  Future<Either<Failure, void>> unblockMedia(String publicId, String reasonCode, String? note) =>
      _guard(
          () => _apiClient.post('/api/media/$publicId/unblock', _reasonBody(reasonCode, note)));

  // Queue (B3, decision 161): `/api/reports/queue` is a literal segment the
  // API registers before `/:id`; the app mirrors that in `ReportsModule`.
  @override
  Future<Either<Failure, QueuePageEntity>> queue(int page, int pageSize) => _guard(() async {
        final uri = Uri(
          path: '/api/reports/queue',
          queryParameters: {'page': '$page', 'pageSize': '$pageSize'},
        );
        return QueuePageEntity.fromJson(await _apiClient.get(uri.toString()));
      });

  /// No body: reviewing carries no reason (161). The detail the API answers
  /// is discarded — the bloc re-fetches, as with every other mutation.
  @override
  Future<Either<Failure, void>> markReviewed(int reportId) =>
      _guard(() => _apiClient.post('/api/reports/$reportId/reviewed', {}));

  // Chat evidence (C3, decision 175): a separate, grant-gated, audited read
  // on the panel plane — same pattern as `getExactPosition`. The query is
  // absent when no limit is asked, so the API default applies.
  @override
  Future<Either<Failure, ReportChatEntity>> getChat(int reportId, {int? limit}) =>
      _guard(() async {
        final uri = Uri(
          path: '/api/reports/$reportId/chat',
          queryParameters: limit == null ? null : {'limit': '$limit'},
        );
        return ReportChatEntity.fromJson(await _apiClient.get(uri.toString()));
      });
}
