import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repository/case_freeze_repository.dart';
import 'case_freeze_event.dart';
import 'case_freeze_state.dart';

/// The minimal freeze screen's flow (decisions 141/142): look a case up,
/// freeze with a mandatory reason, request/approve unfreeze. After every
/// mutation the state is RE-FETCHED — the server is the only authority on
/// what the case is (the approver rule, for one, only it can judge).
class CaseFreezeBloc extends Bloc<CaseFreezeEvent, CaseFreezeState> {
  CaseFreezeBloc(this._repository) : super(const CaseFreezeInitial()) {
    on<CaseLookupRequested>(_onLookup);
    on<CaseFreezeSubmitted>(
        (event, emit) => _mutate(emit, (id) => _repository.freeze(id, event.reason)));
    on<UnfreezeRequestSubmitted>((event, emit) =>
        _mutate(emit, (id) => _repository.requestUnfreeze(id, event.reason)));
    on<UnfreezeApproveSubmitted>(
        (event, emit) => _mutate(emit, _repository.approveUnfreeze));
  }

  final CaseFreezeRepository _repository;
  int? _reportId;

  Future<void> _onLookup(
    CaseLookupRequested event,
    Emitter<CaseFreezeState> emit,
  ) async {
    emit(const CaseFreezeLoading());
    _reportId = event.reportId;
    final result = await _repository.getState(event.reportId);
    if (emit.isDone) return;
    result.fold(
      (failure) => emit(CaseFreezeLookupError(failure)),
      (entity) => emit(CaseFreezeLoaded(entity)),
    );
  }

  Future<void> _mutate(
    Emitter<CaseFreezeState> emit,
    Future<Either<Failure, void>> Function(int reportId) action,
  ) async {
    final current = state;
    final reportId = _reportId;
    if (current is! CaseFreezeLoaded || current.busy || reportId == null) return;

    emit(CaseFreezeLoaded(current.entity, busy: true));
    final result = await action(reportId);
    if (emit.isDone) return;

    final refreshed = await result.fold(
      (failure) async => CaseFreezeLoaded(current.entity, failure: failure),
      (_) async {
        // Success: what the case IS now comes from the server, never from
        // the app guessing the transition.
        final reload = await _repository.getState(reportId);
        return reload.fold(
          (failure) => CaseFreezeLoaded(current.entity, failure: failure),
          CaseFreezeLoaded.new,
        );
      },
    );
    if (emit.isDone) return;
    emit(refreshed);
  }
}
