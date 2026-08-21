import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repository/reward_mediation_repository.dart';
import 'reward_mediation_event.dart';
import 'reward_mediation_state.dart';

/// The mediation screen's flow (decisions 98/148/149/150): look a case's
/// reward up, publish criteria, run the propose -> approve -> window ->
/// execute cycle and close contests. After every mutation the state is
/// RE-FETCHED — the server is the only authority (the distinct-approver
/// and window rules, for two, only it can judge).
class RewardMediationBloc extends Bloc<RewardMediationEvent, RewardMediationState> {
  RewardMediationBloc(this._repository) : super(const MediationInitial()) {
    on<MediationLookupRequested>(_onLookup);
    on<CriteriaPublishSubmitted>(_onPublishCriteria);
    on<ResolutionProposed>((event, emit) =>
        _mutate(emit, (id) => _repository.propose(id, event.outcome, event.reason)));
    on<ResolutionApproved>((event, emit) => _mutate(emit, _repository.approve));
    on<ResolutionCancelled>((event, emit) => _mutate(emit, _repository.cancel));
    on<ResolutionExecuted>((event, emit) => _mutate(emit, _repository.execute));
    on<ContestCloseSubmitted>((event, emit) =>
        _mutate(emit, (_) => _repository.closeContest(event.contestId, event.note)));
  }

  final RewardMediationRepository _repository;
  int? _reportId;

  Future<void> _onLookup(
    MediationLookupRequested event,
    Emitter<RewardMediationState> emit,
  ) async {
    emit(const MediationLoading());
    _reportId = event.reportId;
    final result = await _repository.getState(event.reportId);
    if (emit.isDone) return;
    result.fold(
      (failure) => emit(MediationLookupError(failure)),
      (entity) => emit(MediationLoaded(entity)),
    );
  }

  /// Publishing needs no case on screen — it is the platform-wide act of
  /// decision 150 (append-only; correcting = a new version).
  Future<void> _onPublishCriteria(
    CriteriaPublishSubmitted event,
    Emitter<RewardMediationState> emit,
  ) async {
    if (state is! MediationInitial) return;

    emit(const MediationInitial(criteriaBusy: true));
    final result = await _repository.publishCriteria(event.version, event.body);
    if (emit.isDone) return;
    result.fold(
      (failure) => emit(MediationInitial(criteriaFailure: failure)),
      (_) => emit(const MediationInitial(criteriaPublished: true)),
    );
  }

  Future<void> _mutate(
    Emitter<RewardMediationState> emit,
    Future<Either<Failure, void>> Function(int reportId) action,
  ) async {
    final current = state;
    final reportId = _reportId;
    if (current is! MediationLoaded || current.busy || reportId == null) return;

    emit(MediationLoaded(current.entity, busy: true));
    final result = await action(reportId);
    if (emit.isDone) return;

    final refreshed = await result.fold(
      (failure) async => MediationLoaded(current.entity, failure: failure),
      (_) async {
        // Success: what the case IS now comes from the server, never from
        // the app guessing the transition.
        final reload = await _repository.getState(reportId);
        return reload.fold(
          (failure) => MediationLoaded(current.entity, failure: failure),
          MediationLoaded.new,
        );
      },
    );
    if (emit.isDone) return;
    emit(refreshed);
  }
}
