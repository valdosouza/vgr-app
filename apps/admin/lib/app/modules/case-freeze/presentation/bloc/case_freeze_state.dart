import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entity/case_freeze_state_entity.dart';

sealed class CaseFreezeState extends Equatable {
  const CaseFreezeState();

  @override
  List<Object?> get props => [];
}

/// Search form only — nothing looked up yet.
class CaseFreezeInitial extends CaseFreezeState {
  const CaseFreezeInitial();
}

class CaseFreezeLoading extends CaseFreezeState {
  const CaseFreezeLoading();
}

/// A case is on screen. [busy] while a mutation is in flight; [failure]
/// carries the last action/lookup error without losing the case.
class CaseFreezeLoaded extends CaseFreezeState {
  const CaseFreezeLoaded(this.entity, {this.busy = false, this.failure});

  final CaseFreezeStateEntity entity;
  final bool busy;
  final Failure? failure;

  @override
  List<Object?> get props => [entity, busy, failure];
}

/// The lookup itself failed (not found, purged, no grant).
class CaseFreezeLookupError extends CaseFreezeState {
  const CaseFreezeLookupError(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
