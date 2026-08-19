import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/legal_policy_entities.dart';
import '../../domain/repository/legal_policy_repository.dart';

sealed class CapabilitiesEvent extends Equatable {
  const CapabilitiesEvent();

  @override
  List<Object?> get props => [];
}

class CapabilitiesRequested extends CapabilitiesEvent {
  const CapabilitiesRequested(this.jurisdiction);

  final String jurisdiction;

  @override
  List<Object?> get props => [jurisdiction];
}

sealed class CapabilitiesState extends Equatable {
  const CapabilitiesState();

  @override
  List<Object?> get props => [];
}

/// No jurisdiction picked yet — the catalog only means something FOR a
/// jurisdiction (decision 103).
class CapabilitiesInitial extends CapabilitiesState {
  const CapabilitiesInitial();
}

class CapabilitiesLoading extends CapabilitiesState {
  const CapabilitiesLoading();
}

class CapabilitiesLoaded extends CapabilitiesState {
  const CapabilitiesLoaded(this.jurisdiction, this.rows);

  final String jurisdiction;
  final List<CapabilityOverviewEntity> rows;

  @override
  List<Object?> get props => [jurisdiction, rows];
}

class CapabilitiesError extends CapabilitiesState {
  const CapabilitiesError(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

class CapabilitiesBloc extends Bloc<CapabilitiesEvent, CapabilitiesState> {
  CapabilitiesBloc(this._repository) : super(const CapabilitiesInitial()) {
    on<CapabilitiesRequested>(_onRequested);
  }

  final LegalPolicyRepository _repository;

  Future<void> _onRequested(
    CapabilitiesRequested event,
    Emitter<CapabilitiesState> emit,
  ) async {
    emit(const CapabilitiesLoading());
    final result = await _repository.listCapabilities(event.jurisdiction);
    if (emit.isDone) return;
    result.fold(
      (failure) => emit(CapabilitiesError(failure)),
      (rows) => emit(CapabilitiesLoaded(event.jurisdiction, rows)),
    );
  }
}
