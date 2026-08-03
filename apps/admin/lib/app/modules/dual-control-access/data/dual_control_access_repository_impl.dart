import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../domain/entity/dual_control_access_request_entity.dart';
import '../domain/repository/dual_control_access_repository.dart';

class DualControlAccessRepositoryImpl implements DualControlAccessRepository {
  DualControlAccessRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  DualControlAccessRequestEntity _fromJson(Map<String, dynamic> row) {
    return DualControlAccessRequestEntity(
      id: (row['id'] as int).toString(),
      legalBasis: row['legalBasis'] as String,
      approverIds: (row['approverIds'] as List<dynamic>).cast<String>(),
    );
  }

  @override
  Future<Either<Failure, String>> create(int accountabilityLogEntryId, String legalBasis) async {
    try {
      final json = await _apiClient.post('/api/dual-control-access', {
        'accountabilityLogEntryId': accountabilityLogEntryId,
        'legalBasis': legalBasis,
      });
      final row = json['data'] as Map<String, dynamic>;
      return Right((row['id'] as int).toString());
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, DualControlAccessRequestEntity>> addApproval(String requestId, String approverId) async {
    try {
      final json = await _apiClient.post('/api/dual-control-access/$requestId/approvals', {'approverId': approverId});
      return Right(_fromJson(json['data'] as Map<String, dynamic>));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, List<DualControlAccessRequestEntity>>> findPending() async {
    try {
      final json = await _apiClient.get('/api/dual-control-access');
      final rows = json['data'] as List<dynamic>;
      return Right(rows.map((row) => _fromJson(row as Map<String, dynamic>)).toList());
    } on Failure catch (f) {
      return Left(f);
    }
  }
}
