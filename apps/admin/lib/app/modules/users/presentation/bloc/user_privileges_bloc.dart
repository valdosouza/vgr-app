import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/user_entity.dart';
import '../../domain/repository/user_repository.dart';

sealed class UserPrivilegesEvent extends Equatable {
  const UserPrivilegesEvent();

  @override
  List<Object?> get props => [];
}

class UserPrivilegesFetchRequested extends UserPrivilegesEvent {
  const UserPrivilegesFetchRequested(this.userId);

  final int userId;

  @override
  List<Object?> get props => [userId];
}

/// Grants the listed privileges on one screen (revoking the rest). The API
/// implies VIEW on any grant, so the matrix is re-fetched afterwards to
/// reflect the effective result.
class UserInterfaceGrantsSubmitted extends UserPrivilegesEvent {
  const UserInterfaceGrantsSubmitted({
    required this.userId,
    required this.interfaceId,
    required this.privilegeIds,
  });

  final int userId;
  final int interfaceId;
  final List<int> privilegeIds;

  @override
  List<Object?> get props => [userId, interfaceId, privilegeIds];
}

sealed class UserPrivilegesState extends Equatable {
  const UserPrivilegesState();

  @override
  List<Object?> get props => [];
}

class UserPrivilegesLoading extends UserPrivilegesState {
  const UserPrivilegesLoading();
}

class UserPrivilegesLoaded extends UserPrivilegesState {
  const UserPrivilegesLoaded(this.matrix, {this.actionError, this.saved = false});

  final List<UserInterfaceGrants> matrix;
  final Failure? actionError;

  /// One-shot flag: the latest sync succeeded (page shows feedback).
  final bool saved;

  @override
  List<Object?> get props => [matrix, actionError, saved];
}

class UserPrivilegesError extends UserPrivilegesState {
  const UserPrivilegesError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class UserPrivilegesBloc extends Bloc<UserPrivilegesEvent, UserPrivilegesState> {
  UserPrivilegesBloc(this._repository) : super(const UserPrivilegesLoading()) {
    on<UserPrivilegesFetchRequested>(_onFetch);
    on<UserInterfaceGrantsSubmitted>(_onSubmitted);
  }

  final UserRepository _repository;

  Future<void> _onFetch(
    UserPrivilegesFetchRequested event,
    Emitter<UserPrivilegesState> emit,
  ) async {
    emit(const UserPrivilegesLoading());
    final result = await _repository.privilegeMatrix(event.userId);
    result.fold(
      (failure) => emit(UserPrivilegesError(failure.message)),
      (matrix) => emit(UserPrivilegesLoaded(matrix)),
    );
  }

  Future<void> _onSubmitted(
    UserInterfaceGrantsSubmitted event,
    Emitter<UserPrivilegesState> emit,
  ) async {
    final current = state;
    if (current is! UserPrivilegesLoaded) return;

    final result = await _repository.syncPrivileges(
      event.userId,
      event.interfaceId,
      event.privilegeIds,
    );

    await result.fold(
      (failure) async => emit(UserPrivilegesLoaded(current.matrix, actionError: failure)),
      (_) async {
        // Re-fetch: the API may have implied VIEW beyond what was sent.
        final refreshed = await _repository.privilegeMatrix(event.userId);
        refreshed.fold(
          (failure) => emit(UserPrivilegesError(failure.message)),
          (matrix) => emit(UserPrivilegesLoaded(matrix, saved: true)),
        );
      },
    );
  }
}
