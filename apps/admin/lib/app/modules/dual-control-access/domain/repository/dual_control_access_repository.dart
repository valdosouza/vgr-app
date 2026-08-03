import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/dual_control_access_request_entity.dart';

abstract class DualControlAccessRepository {
  Future<Either<Failure, String>> create(int accountabilityLogEntryId, String legalBasis);
  Future<Either<Failure, DualControlAccessRequestEntity>> addApproval(String requestId, String approverId);
  Future<Either<Failure, List<DualControlAccessRequestEntity>>> findPending();
}
