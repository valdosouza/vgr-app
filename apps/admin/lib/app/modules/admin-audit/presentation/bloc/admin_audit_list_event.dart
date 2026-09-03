import 'package:equatable/equatable.dart';

import '../../domain/entity/admin_audit_entities.dart';

sealed class AdminAuditListEvent extends Equatable {
  const AdminAuditListEvent();

  @override
  List<Object?> get props => [];
}

/// Screen entry: facets for the dropdowns + the first page, no filter.
class AdminAuditListStarted extends AdminAuditListEvent {
  const AdminAuditListStarted();
}

/// New filters → back to page 1 (facets kept).
class AdminAuditSearchRequested extends AdminAuditListEvent {
  const AdminAuditSearchRequested(this.filters);

  final AuditFiltersEntity filters;

  @override
  List<Object?> get props => [filters];
}

/// Prev/next under the CURRENT filters.
class AdminAuditPageRequested extends AdminAuditListEvent {
  const AdminAuditPageRequested(this.page);

  final int page;

  @override
  List<Object?> get props => [page];
}
