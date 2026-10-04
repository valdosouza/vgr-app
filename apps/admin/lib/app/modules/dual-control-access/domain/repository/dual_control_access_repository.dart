import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/dual_control_request_entity.dart';

/// `/api/dual-control-access` (decisions 45, 223–227). There is no
/// approver argument anywhere: the API takes both people from the session.
abstract class DualControlAccessRepository {
  /// Newest first; `filter` matches the legal basis (decision 220).
  Future<Either<Failure, PagedResult<DualControlRequestEntity>>> list(PagedQuery query);

  /// Opens a request — the session user becomes its requester and first
  /// authorization (decision 224).
  Future<Either<Failure, DualControlRequestEntity>> request(DualControlRequestDraft draft);

  /// Approves as the session user; the API refuses the requester (422) and
  /// a request that is no longer pending (409).
  Future<Either<Failure, DualControlRequestEntity>> approve(int id);
}
