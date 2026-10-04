import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/register/register_bloc.dart';
import '../../domain/entity/legal_policy_entities.dart';
import '../../domain/repository/legal_policy_repository.dart';

export '../../../../shared/register/register_bloc.dart';

/// The type the rules screen and its route share (RulesBloc is provided
/// under it — `RegisterScreen` looks the factory's base type up).
typedef RulesRegisterBloc = RegisterBloc<LegalRuleEntity, LegalRuleProposal>;

class RuleApproved extends RegisterEvent {
  const RuleApproved(this.id);

  final int id;

  @override
  List<Object?> get props => [id];
}

class RuleRejected extends RegisterEvent {
  const RuleRejected(this.id);

  final int id;

  @override
  List<Object?> get props => [id];
}

/// Rule administration (decisions 107/108) on the register factory: the
/// form only PROPOSES — a rule is versioned, so a change is a new proposal,
/// never an edit or a delete — and a DIFFERENT user approves (activation
/// supersedes the previous version) or rejects from the row. Every action
/// reloads under the current query: versions and states are the server's
/// story, never assembled client-side.
class RulesBloc extends RulesRegisterBloc {
  RulesBloc(LegalPolicyRepository repository) : super(_RuleRegister(repository)) {
    on<RuleApproved>((event, emit) => act(emit, () => repository.approveRule(event.id)));
    on<RuleRejected>((event, emit) => act(emit, () => repository.rejectRule(event.id)));
  }
}

/// The rule screen as the factory sees it: list + propose. Rules have no
/// edit and no delete (versioned, decision 107) — the screen keeps rows
/// closed, so the factory never asks for either.
class _RuleRegister implements RegisterRepository<LegalRuleEntity, LegalRuleProposal> {
  _RuleRegister(this._repository);

  final LegalPolicyRepository _repository;

  @override
  Future<Either<Failure, PagedResult<LegalRuleEntity>>> list(PagedQuery query) =>
      _repository.listRules(query);

  @override
  Future<Either<Failure, LegalRuleEntity>> create(LegalRuleProposal draft) =>
      _repository.proposeRule(draft);

  @override
  Future<Either<Failure, LegalRuleEntity>> update(LegalRuleEntity current, LegalRuleProposal draft) =>
      throw UnsupportedError('A legal rule is versioned: propose a new one (decision 107).');

  @override
  Future<Either<Failure, Unit>> delete(LegalRuleEntity item) =>
      throw UnsupportedError('A legal rule is versioned: it is superseded, never deleted (107).');
}
