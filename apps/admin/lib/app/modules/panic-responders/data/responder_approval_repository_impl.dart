import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../domain/entity/responder_approval_entity.dart';
import '../domain/repository/responder_approval_repository.dart';

class ResponderApprovalRepositoryImpl implements ResponderApprovalRepository {
  ResponderApprovalRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Either<Failure, List<ResponderApprovalEntity>>> listPending() async {
    try {
      final json = await _apiClient.get('/api/panic/responder-pool');
      final rows = json['data'] as List<dynamic>;
      return Right(rows
          .map((row) => ResponderApprovalEntity(
                id: row['id'] as int,
                userId: row['userId'] as int,
                status: ResponderApprovalStatusJson.fromJson(row['status'] as String),
                criteriaNotes: row['criteriaNotes'] as String?,
              ))
          .toList());
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
