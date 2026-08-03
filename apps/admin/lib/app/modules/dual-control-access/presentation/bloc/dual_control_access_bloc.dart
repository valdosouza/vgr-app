import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/dual_control_access_request_entity.dart';
import '../../domain/repository/dual_control_access_repository.dart';
import 'dual_control_access_event.dart';
import 'dual_control_access_state.dart';

class DualControlAccessBloc extends Bloc<DualControlAccessEvent, DualControlAccessState> {
  DualControlAccessBloc(this._repository) : super(const DualControlInitial()) {
    on<RequestSubmitted>(_onRequestSubmitted);
    on<ApprovalSubmitted>(_onApprovalSubmitted);
  }

  final DualControlAccessRepository _repository;
  String? _requestId;

  Future<void> _onRequestSubmitted(
    RequestSubmitted event,
    Emitter<DualControlAccessState> emit,
  ) async {
    final result = await _repository.create(event.accountabilityLogEntryId, event.legalBasis);
    result.fold(
      (failure) => emit(DualControlError(failure.message)),
      (id) {
        _requestId = id;
        emit(DualControlProgress(
          DualControlAccessRequestEntity(id: id, legalBasis: event.legalBasis, approverIds: const []),
        ));
      },
    );
  }

  /// [DualControlActionSuccess] fires only when this specific call is the
  /// one that pushes `isGrantable` to true — never on the first approval.
  Future<void> _onApprovalSubmitted(
    ApprovalSubmitted event,
    Emitter<DualControlAccessState> emit,
  ) async {
    final requestId = _requestId;
    if (requestId == null) return;

    final result = await _repository.addApproval(requestId, event.approverId);
    result.fold(
      (failure) => emit(DualControlError(failure.message)),
      (entity) => emit(entity.isGrantable ? DualControlActionSuccess(entity) : DualControlProgress(entity)),
    );
  }
}
