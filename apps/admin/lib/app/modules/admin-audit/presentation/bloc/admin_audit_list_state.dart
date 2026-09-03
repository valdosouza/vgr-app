import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entity/admin_audit_entities.dart';

sealed class AdminAuditListState extends Equatable {
  const AdminAuditListState();

  @override
  List<Object?> get props => [];
}

/// Before entry — the page dispatches [AdminAuditListStarted] itself.
class AdminAuditListInitial extends AdminAuditListState {
  const AdminAuditListInitial();
}

/// [facets] is `null` only during the entry load (facets not yet known).
class AdminAuditListLoading extends AdminAuditListState {
  const AdminAuditListLoading(this.filters, this.facets);

  final AuditFiltersEntity filters;
  final AuditFacetsEntity? facets;

  @override
  List<Object?> get props => [filters, facets];
}

class AdminAuditListLoaded extends AdminAuditListState {
  const AdminAuditListLoaded(this.page, this.filters, this.facets);

  final AuditPageEntity page;
  final AuditFiltersEntity filters;
  final AuditFacetsEntity facets;

  @override
  List<Object?> get props => [page, filters, facets];
}

/// The list read failed (403 without the grant, 422 on a bad filter,
/// network). Facets, when already known, are kept so the bar stays usable.
class AdminAuditListError extends AdminAuditListState {
  const AdminAuditListError(this.failure, this.filters, this.facets);

  final Failure failure;
  final AuditFiltersEntity filters;
  final AuditFacetsEntity facets;

  @override
  List<Object?> get props => [failure, filters, facets];
}
