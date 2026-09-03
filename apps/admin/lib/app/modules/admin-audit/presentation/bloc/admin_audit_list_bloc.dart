import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/admin_audit_entities.dart';
import '../../domain/repository/admin_audit_repository.dart';
import 'admin_audit_list_event.dart';
import 'admin_audit_list_state.dart';

/// Admin audit trail list (B5, decisions 116/166): facets + first page on
/// entry, filters → page 1, prev/next under the same filters. A facets
/// refusal never blocks the list — the dropdowns are a convenience, the
/// trail is the point. Nothing is cached: every answer replaces the last.
class AdminAuditListBloc extends Bloc<AdminAuditListEvent, AdminAuditListState> {
  AdminAuditListBloc(this._repository, {this.pageSize = 50})
      : super(const AdminAuditListInitial()) {
    on<AdminAuditListStarted>(_onStarted);
    on<AdminAuditSearchRequested>((event, emit) => _load(emit, event.filters, 1));
    on<AdminAuditPageRequested>(_onPage);
  }

  final AdminAuditRepository _repository;
  final int pageSize;
  AuditFiltersEntity? _filters;
  AuditFacetsEntity? _facets;

  Future<void> _onStarted(AdminAuditListStarted event, Emitter<AdminAuditListState> emit) async {
    const filters = AuditFiltersEntity();
    _filters = filters;
    emit(const AdminAuditListLoading(filters, null));
    // Both reads in flight together; neither waits for the other.
    final facetsFuture = _repository.facets();
    final listFuture = _repository.list(filters, 1, pageSize);
    final facets = (await facetsFuture).fold((_) => AuditFacetsEntity.empty, (f) => f);
    final listResult = await listFuture;
    if (emit.isDone) return;
    _facets = facets;
    listResult.fold(
      (failure) => emit(AdminAuditListError(failure, filters, facets)),
      (page) => emit(AdminAuditListLoaded(page, filters, facets)),
    );
  }

  Future<void> _onPage(AdminAuditPageRequested event, Emitter<AdminAuditListState> emit) async {
    final filters = _filters;
    if (filters == null) return;
    await _load(emit, filters, event.page);
  }

  Future<void> _load(
    Emitter<AdminAuditListState> emit,
    AuditFiltersEntity filters,
    int page,
  ) async {
    final facets = _facets ?? AuditFacetsEntity.empty;
    _filters = filters;
    emit(AdminAuditListLoading(filters, facets));
    final result = await _repository.list(filters, page, pageSize);
    if (emit.isDone) return;
    result.fold(
      (failure) => emit(AdminAuditListError(failure, filters, facets)),
      (loaded) => emit(AdminAuditListLoaded(loaded, filters, facets)),
    );
  }
}
