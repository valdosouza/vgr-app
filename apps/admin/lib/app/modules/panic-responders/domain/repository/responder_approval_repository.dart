import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/responder_approval_entity.dart';

abstract class ResponderApprovalRepository {
  /// One page of the PENDING queue, oldest first (PS0, decision 220 — no
  /// text filter: the row carries no applicant name or e-mail).
  Future<Either<Failure, PagedResult<ResponderApprovalEntity>>> listPending(PagedQuery query);

  Future<Either<Failure, Unit>> resolve(int id, bool approved);
}
