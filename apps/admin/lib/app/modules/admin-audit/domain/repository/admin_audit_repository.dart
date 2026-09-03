import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/admin_audit_entities.dart';

/// Contract of the admin audit trail screen, phase B5 (decisions 116/158/
/// 165/166): READ only, behind the `admin_audit` VIEW grant. There is no
/// write here and never will be — `tb_admin_audit` is append-only by the
/// API alone (116). Reading the trail is itself NOT audited (166).
abstract class AdminAuditRepository {
  Future<Either<Failure, AuditPageEntity>> list(
    AuditFiltersEntity filters,
    int page,
    int pageSize,
  );

  /// The ONE read that carries the operator `ip` (personal data).
  Future<Either<Failure, AuditEntryEntity>> get(int id);

  Future<Either<Failure, AuditFacetsEntity>> facets();
}
