import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/legal_policy_entities.dart';
import '../../domain/repository/legal_policy_repository.dart';

sealed class JurisdictionsEvent extends Equatable {
  const JurisdictionsEvent();

  @override
  List<Object?> get props => [];
}

class JurisdictionsRequested extends JurisdictionsEvent {
  const JurisdictionsRequested();
}

class JurisdictionStateRequested extends JurisdictionsEvent {
  const JurisdictionStateRequested(this.code, this.state);

  final String code;
  final String state;

  @override
  List<Object?> get props => [code, state];
}

class JurisdictionStateConfirmed extends JurisdictionsEvent {
  const JurisdictionStateConfirmed(this.code);

  final String code;

  @override
  List<Object?> get props => [code];
}

sealed class JurisdictionsState extends Equatable {
  const JurisdictionsState();

  @override
  List<Object?> get props => [];
}

class JurisdictionsLoading extends JurisdictionsState {
  const JurisdictionsLoading();
}

class JurisdictionsLoaded extends JurisdictionsState {
  const JurisdictionsLoaded(this.rows, {this.failure});

  final List<JurisdictionEntity> rows;

  /// Last action failure — the list stays usable.
  final Failure? failure;

  @override
  List<Object?> get props => [rows, failure];
}

class JurisdictionsError extends JurisdictionsState {
  const JurisdictionsError(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// Kill-switch screen flow (decision 107): tightening applies with one
/// holder; loosening waits as pending for a DIFFERENT confirmer. After
/// every action the LIST is reloaded — the server owns the semantics.
class JurisdictionsBloc extends Bloc<JurisdictionsEvent, JurisdictionsState> {
  JurisdictionsBloc(this._repository) : super(const JurisdictionsLoading()) {
    on<JurisdictionsRequested>((_, emit) => _reload(emit));
    on<JurisdictionStateRequested>((event, emit) =>
        _act(emit, () => _repository.requestState(event.code, event.state)));
    on<JurisdictionStateConfirmed>(
        (event, emit) => _act(emit, () => _repository.confirmState(event.code)));
  }

  final LegalPolicyRepository _repository;

  Future<void> _reload(Emitter<JurisdictionsState> emit, {Failure? failure}) async {
    final result = await _repository.listJurisdictions();
    if (emit.isDone) return;
    result.fold(
      (loadFailure) => emit(JurisdictionsError(loadFailure)),
      (rows) => emit(JurisdictionsLoaded(rows, failure: failure)),
    );
  }

  Future<void> _act(
    Emitter<JurisdictionsState> emit,
    Future<Either<Failure, JurisdictionEntity>> Function() action,
  ) async {
    if (state is! JurisdictionsLoaded) return;
    final result = await action();
    if (emit.isDone) return;
    await result.fold(
      (failure) => _reload(emit, failure: failure),
      (_) => _reload(emit),
    );
  }
}
