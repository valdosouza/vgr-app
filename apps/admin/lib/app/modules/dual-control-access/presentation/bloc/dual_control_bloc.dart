import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/register/register_bloc.dart';
import '../../domain/entity/dual_control_request_entity.dart';
import '../../domain/repository/dual_control_access_repository.dart';

export '../../../../shared/register/register_bloc.dart';

/// The type the screen and its route share (DualControlBloc is provided
/// under it — `RegisterScreen` looks the factory's base type up).
typedef DualControlRegisterBloc = RegisterBloc<DualControlRequestEntity, DualControlRequestDraft>;

class DualControlApproved extends RegisterEvent {
  const DualControlApproved(this.id);

  final int id;

  @override
  List<Object?> get props => [id];
}

/// The decision 45 gate on the register factory (decision 227, the design
/// of the Legal Gate rules): the form only OPENS a request, a request is
/// never edited or deleted, and a DIFFERENT user approves it from its row.
/// Every action reloads under the current query — who approved and when
/// is the server's story, never assembled client-side.
class DualControlBloc extends DualControlRegisterBloc {
  DualControlBloc(DualControlAccessRepository repository) : super(_DualControlRegister(repository)) {
    on<DualControlApproved>(
      (event, emit) => act(emit, () => repository.approve(event.id), successKey: approvedKey),
    );
  }

  static const approvedKey = 'dualControl.approvedFeedback';
}

/// The request screen as the factory sees it: list + open. A request has
/// no edit and no delete — it is the record of who asked for what (45(c))
/// — so the screen keeps rows closed and the factory never asks for either.
class _DualControlRegister implements RegisterRepository<DualControlRequestEntity, DualControlRequestDraft> {
  _DualControlRegister(this._repository);

  final DualControlAccessRepository _repository;

  @override
  Future<Either<Failure, PagedResult<DualControlRequestEntity>>> list(PagedQuery query) =>
      _repository.list(query);

  @override
  Future<Either<Failure, DualControlRequestEntity>> create(DualControlRequestDraft draft) =>
      _repository.request(draft);

  @override
  Future<Either<Failure, DualControlRequestEntity>> update(
    DualControlRequestEntity current,
    DualControlRequestDraft draft,
  ) =>
      throw UnsupportedError('A dual-control request is never edited (decision 45(c)).');

  @override
  Future<Either<Failure, Unit>> delete(DualControlRequestEntity item) =>
      throw UnsupportedError('A dual-control request is never deleted (decision 45(c)).');
}
