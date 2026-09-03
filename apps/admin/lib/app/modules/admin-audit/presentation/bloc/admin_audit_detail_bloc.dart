import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repository/admin_audit_repository.dart';
import 'admin_audit_detail_event.dart';
import 'admin_audit_detail_state.dart';

/// ONE audit entry (B5): the only read that carries the operator `ip`.
/// Not audited itself (166) — nothing to re-fetch, nothing to mutate.
class AdminAuditDetailBloc extends Bloc<AdminAuditDetailEvent, AdminAuditDetailState> {
  AdminAuditDetailBloc(this._repository) : super(const AdminAuditDetailInitial()) {
    on<AdminAuditDetailRequested>(_onRequested);
  }

  final AdminAuditRepository _repository;

  Future<void> _onRequested(
    AdminAuditDetailRequested event,
    Emitter<AdminAuditDetailState> emit,
  ) async {
    emit(const AdminAuditDetailLoading());
    final result = await _repository.get(event.id);
    if (emit.isDone) return;
    result.fold(
      (failure) => emit(AdminAuditDetailError(failure)),
      (entry) => emit(AdminAuditDetailLoaded(entry)),
    );
  }
}
