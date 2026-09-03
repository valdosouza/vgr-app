import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../domain/entity/admin_audit_entities.dart';
import '../domain/repository/admin_audit_repository.dart';

class AdminAuditRepositoryImpl implements AdminAuditRepository {
  AdminAuditRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Right(await run());
    } on Failure catch (f) {
      return Left(f);
    }
  }

  /// `GET /api/admin-audit?page&pageSize[&actorId&action&entity&entityId&from&to]`.
  /// Path + query built by Uri so every value is encoded once; unset
  /// filters are simply absent.
  @override
  Future<Either<Failure, AuditPageEntity>> list(
    AuditFiltersEntity filters,
    int page,
    int pageSize,
  ) =>
      _guard(() async {
        final uri = Uri(
          path: '/api/admin-audit',
          queryParameters: {
            'page': '$page',
            'pageSize': '$pageSize',
            ...filters.toQueryParameters(),
          },
        );
        return AuditPageEntity.fromJson(await _apiClient.get(uri.toString()));
      });

  @override
  Future<Either<Failure, AuditEntryEntity>> get(int id) =>
      _guard(() async => AuditEntryEntity.fromJson(await _apiClient.get('/api/admin-audit/$id')));

  /// `/facets` is a literal segment the API registers BEFORE `/:id`.
  @override
  Future<Either<Failure, AuditFacetsEntity>> facets() => _guard(
      () async => AuditFacetsEntity.fromJson(await _apiClient.get('/api/admin-audit/facets')));
}
