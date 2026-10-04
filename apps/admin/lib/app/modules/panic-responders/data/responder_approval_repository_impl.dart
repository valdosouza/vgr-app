import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../domain/entity/responder_approval_entity.dart';
import '../domain/repository/responder_approval_repository.dart';

class ResponderApprovalRepositoryImpl implements ResponderApprovalRepository {
  ResponderApprovalRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Either<Failure, PagedResult<ResponderApprovalEntity>>> listPending(PagedQuery query) async {
    try {
      // The queue has no text to match: only page and size travel.
      final json = await _apiClient.get(
        '/api/panic/responder-pool?${PagedQuery(page: query.page, pageSize: query.pageSize).toQueryString()}',
      );
      return Right(PagedResult.fromJson(
        json['data'] as Map<String, dynamic>,
        (row) => ResponderApprovalEntity(
          id: row['id'] as int,
          userId: row['userId'] as int,
          status: ResponderApprovalStatusJson.fromJson(row['status'] as String),
          criteriaNotes: row['criteriaNotes'] as String?,
        ),
      ));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, Unit>> resolve(int id, bool approved) async {
    try {
      await _apiClient.put('/api/panic/responder-pool/$id/resolve', {'approved': approved});
      return const Right(unit);
    } on Failure catch (f) {
      return Left(f);
    }
  }
}
