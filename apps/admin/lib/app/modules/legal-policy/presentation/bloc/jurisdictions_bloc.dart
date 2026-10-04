import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/register/paged_list_bloc.dart';
import '../../../../shared/register/register_event.dart';
import '../../domain/entity/legal_policy_entities.dart';
import '../../domain/repository/legal_policy_repository.dart';

export '../../../../shared/register/register_event.dart';
export '../../../../shared/register/register_state.dart';

class JurisdictionStateRequested extends RegisterEvent {
  const JurisdictionStateRequested(this.code, this.state);

  final String code;
  final String state;

  @override
  List<Object?> get props => [code, state];
}

class JurisdictionStateConfirmed extends RegisterEvent {
  const JurisdictionStateConfirmed(this.code);

  final String code;

  @override
  List<Object?> get props => [code];
}

/// Kill-switch screen flow (decision 107): tightening applies with one
/// holder; loosening waits as pending for a DIFFERENT confirmer. A paged
/// list (decision 220) whose row actions go through `act`: the outcome
/// reaches the feedback bridge (221) and the page is reloaded quietly —
/// the server owns the semantics.
class JurisdictionsBloc extends PagedListBloc<JurisdictionEntity> {
  JurisdictionsBloc(this._repository) {
    on<JurisdictionStateRequested>(
        (event, emit) => act(emit, () => _repository.requestState(event.code, event.state)));
    on<JurisdictionStateConfirmed>(
        (event, emit) => act(emit, () => _repository.confirmState(event.code)));
  }

  final LegalPolicyRepository _repository;

  @override
  Future<Either<Failure, PagedResult<JurisdictionEntity>>> fetch(PagedQuery query) =>
      _repository.listJurisdictions(query);
}
