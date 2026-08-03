import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/responder_approval_entity.dart';

abstract class ResponderApprovalRepository {
  Future<Either<Failure, List<ResponderApprovalEntity>>> listPending();
  Future<Either<Failure, Unit>> resolve(int id, bool approved);
}
