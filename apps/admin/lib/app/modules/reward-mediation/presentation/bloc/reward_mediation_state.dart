import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entity/reward_mediation_state_entity.dart';

sealed class RewardMediationState extends Equatable {
  const RewardMediationState();

  @override
  List<Object?> get props => [];
}

/// Search form (plus the publish-criteria section) — nothing looked up
/// yet. [criteriaBusy]/[criteriaPublished]/[criteriaFailure] carry the
/// publish flow, which needs no case on screen (decision 150).
class MediationInitial extends RewardMediationState {
  const MediationInitial({
    this.criteriaBusy = false,
    this.criteriaPublished = false,
    this.criteriaFailure,
  });

  final bool criteriaBusy;
  final bool criteriaPublished;
  final Failure? criteriaFailure;

  @override
  List<Object?> get props => [criteriaBusy, criteriaPublished, criteriaFailure];
}

class MediationLoading extends RewardMediationState {
  const MediationLoading();
}

/// A case's reward is on screen. [busy] while a mutation is in flight;
/// [failure] carries the last action error without losing the case.
class MediationLoaded extends RewardMediationState {
  const MediationLoaded(this.entity, {this.busy = false, this.failure});

  final RewardMediationStateEntity entity;
  final bool busy;
  final Failure? failure;

  @override
  List<Object?> get props => [entity, busy, failure];
}

/// The lookup itself failed (no offer, no grant).
class MediationLookupError extends RewardMediationState {
  const MediationLookupError(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
