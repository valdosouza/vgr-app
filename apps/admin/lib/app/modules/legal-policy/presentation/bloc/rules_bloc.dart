import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/legal_policy_entities.dart';
import '../../domain/repository/legal_policy_repository.dart';

sealed class RulesEvent extends Equatable {
  const RulesEvent();

  @override
  List<Object?> get props => [];
}

class RulesRequested extends RulesEvent {
  const RulesRequested({this.capability, this.jurisdiction});

  final String? capability;
  final String? jurisdiction;

  @override
  List<Object?> get props => [capability, jurisdiction];
}

class RuleProposed extends RulesEvent {
  const RuleProposed(this.proposal);

  final LegalRuleProposal proposal;

  @override
  List<Object?> get props => [proposal];
}

class RuleApproved extends RulesEvent {
  const RuleApproved(this.id);

  final int id;

  @override
  List<Object?> get props => [id];
}

class RuleRejected extends RulesEvent {
  const RuleRejected(this.id);

  final int id;

  @override
  List<Object?> get props => [id];
}

sealed class RulesState extends Equatable {
  const RulesState();

  @override
  List<Object?> get props => [];
}

class RulesLoading extends RulesState {
  const RulesLoading();
}

class RulesLoaded extends RulesState {
  const RulesLoaded(this.rows, {this.failure});

  /// Version history, newest first per capability×jurisdiction (plan §6).
  final List<LegalRuleEntity> rows;

  /// Last action failure — the list stays usable.
  final Failure? failure;

  @override
  List<Object?> get props => [rows, failure];
}

class RulesError extends RulesState {
  const RulesError(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// Rule administration (decisions 107/108): propose → a DIFFERENT user
/// approves (activation supersedes the previous version) or rejects.
/// Every action reloads under the current filter — versions and states
/// are the server's story, never assembled client-side.
class RulesBloc extends Bloc<RulesEvent, RulesState> {
  RulesBloc(this._repository) : super(const RulesLoading()) {
    on<RulesRequested>(_onRequested);
    on<RuleProposed>(
        (event, emit) => _act(emit, () => _repository.proposeRule(event.proposal)));
    on<RuleApproved>(
        (event, emit) => _act(emit, () => _repository.approveRule(event.id)));
    on<RuleRejected>(
        (event, emit) => _act(emit, () => _repository.rejectRule(event.id)));
  }

  final LegalPolicyRepository _repository;
  String? _capability;
  String? _jurisdiction;

  Future<void> _onRequested(RulesRequested event, Emitter<RulesState> emit) async {
    _capability = event.capability;
    _jurisdiction = event.jurisdiction;
    emit(const RulesLoading());
    await _reload(emit);
  }

  Future<void> _reload(Emitter<RulesState> emit, {Failure? failure}) async {
    final result = await _repository.listRules(
      capability: _capability,
      jurisdiction: _jurisdiction,
    );
    if (emit.isDone) return;
    result.fold(
      (loadFailure) => emit(RulesError(loadFailure)),
      (rows) => emit(RulesLoaded(rows, failure: failure)),
    );
  }

  Future<void> _act(
    Emitter<RulesState> emit,
    Future<Either<Failure, LegalRuleEntity>> Function() action,
  ) async {
    if (state is! RulesLoaded) return;
    final result = await action();
    if (emit.isDone) return;
    await result.fold(
      (failure) => _reload(emit, failure: failure),
      (_) => _reload(emit),
    );
  }
}
