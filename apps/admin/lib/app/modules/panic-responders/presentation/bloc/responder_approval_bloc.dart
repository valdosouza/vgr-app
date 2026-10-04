import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/register/paged_list_bloc.dart';
import '../../../../shared/register/register_event.dart';
import '../../domain/entity/responder_approval_entity.dart';
import '../../domain/repository/responder_approval_repository.dart';

export '../../../../shared/register/register_event.dart';
export '../../../../shared/register/register_state.dart';

/// Approves or denies one pending request (decisions 51-52).
class ResolveRequested extends RegisterEvent {
  const ResolveRequested({required this.id, required this.approved});

  final int id;
  final bool approved;

  @override
  List<Object?> get props => [id, approved];
}

/// The authorized-responder queue as a paged list (decision 220). Resolving
/// runs through `act`: the outcome reaches the feedback bridge (221) and the
/// page is reloaded quietly, so the resolved request leaves because the
/// server says so — and a refusal keeps the queue on screen instead of
/// replacing it with an error.
class ResponderApprovalBloc extends PagedListBloc<ResponderApprovalEntity> {
  ResponderApprovalBloc(this._repository) {
    on<ResolveRequested>((event, emit) => act(
          emit,
          () => _repository.resolve(event.id, event.approved),
          successKey: event.approved ? 'panicResponders.approved' : 'panicResponders.denied',
        ));
  }

  final ResponderApprovalRepository _repository;

  @override
  Future<Either<Failure, PagedResult<ResponderApprovalEntity>>> fetch(PagedQuery query) =>
      _repository.listPending(query);
}
