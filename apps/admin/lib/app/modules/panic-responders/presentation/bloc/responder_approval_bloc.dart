import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repository/responder_approval_repository.dart';
import 'responder_approval_event.dart';
import 'responder_approval_state.dart';

class ResponderApprovalBloc extends Bloc<ResponderApprovalEvent, ResponderApprovalState> {
  ResponderApprovalBloc(this._repository) : super(const ResponderApprovalLoading()) {
    on<FetchRequested>(_onFetchRequested);
    on<ResolveRequested>(_onResolveRequested);
  }

  final ResponderApprovalRepository _repository;

  Future<void> _onFetchRequested(
    FetchRequested event,
    Emitter<ResponderApprovalState> emit,
  ) async {
    emit(const ResponderApprovalLoading());
    final result = await _repository.listPending();
    result.fold(
      (failure) => emit(ResponderApprovalError(failure.message)),
      (items) => emit(ResponderApprovalLoaded(items)),
    );
  }

  /// Removes the item locally instead of re-fetching the whole queue —
  /// this is what "removes the request from the pending queue" means (task 05).
  Future<void> _onResolveRequested(
    ResolveRequested event,
    Emitter<ResponderApprovalState> emit,
  ) async {
    final result = await _repository.resolve(event.id, event.approved);
    result.fold(
      (failure) => emit(ResponderApprovalError(failure.message)),
      (_) {
        final current = state;
        if (current is ResponderApprovalLoaded) {
          emit(ResponderApprovalLoaded(
            current.items.where((item) => item.id != event.id).toList(),
          ));
        }
      },
    );
  }
}
