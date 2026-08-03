import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/user_entity.dart';
import '../../domain/repository/user_repository.dart';

sealed class UserEvent extends Equatable {
  const UserEvent();

  @override
  List<Object?> get props => [];
}

class UserFetchRequested extends UserEvent {
  const UserFetchRequested();
}

class UserSaved extends UserEvent {
  const UserSaved({
    this.id,
    required this.name,
    required this.email,
    required this.active,
    this.password,
  });

  /// null = create (password then required by the API).
  final int? id;
  final String name;
  final String email;
  final String active;
  final String? password;

  @override
  List<Object?> get props => [id, name, email, active, password];
}

class UserDeleted extends UserEvent {
  const UserDeleted(this.id);

  final int id;

  @override
  List<Object?> get props => [id];
}

sealed class UserState extends Equatable {
  const UserState();

  @override
  List<Object?> get props => [];
}

class UserLoading extends UserState {
  const UserLoading();
}

class UserLoaded extends UserState {
  const UserLoaded(this.items, {this.actionError});

  final List<UserEntity> items;
  final Failure? actionError;

  @override
  List<Object?> get props => [items, actionError];
}

class UserError extends UserState {
  const UserError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class UserBloc extends Bloc<UserEvent, UserState> {
  UserBloc(this._repository) : super(const UserLoading()) {
    on<UserFetchRequested>(_onFetch);
    on<UserSaved>(_onSaved);
    on<UserDeleted>(_onDeleted);
  }

  final UserRepository _repository;

  Future<void> _onFetch(UserFetchRequested event, Emitter<UserState> emit) async {
    emit(const UserLoading());
    final result = await _repository.list();
    result.fold(
      (failure) => emit(UserError(failure.message)),
      (items) => emit(UserLoaded(items)),
    );
  }

  Future<void> _onSaved(UserSaved event, Emitter<UserState> emit) async {
    final current = state;
    if (current is! UserLoaded) return;

    final result = event.id == null
        ? await _repository.create(
            name: event.name,
            email: event.email,
            active: event.active,
            password: event.password ?? '',
          )
        : await _repository.update(
            id: event.id!,
            name: event.name,
            email: event.email,
            active: event.active,
            password: event.password,
          );

    result.fold(
      (failure) => emit(UserLoaded(current.items, actionError: failure)),
      (saved) {
        final items = [...current.items.where((u) => u.id != saved.id), saved]
          ..sort((a, b) => a.name.compareTo(b.name));
        emit(UserLoaded(items));
      },
    );
  }

  Future<void> _onDeleted(UserDeleted event, Emitter<UserState> emit) async {
    final current = state;
    if (current is! UserLoaded) return;

    final result = await _repository.delete(event.id);
    result.fold(
      (failure) => emit(UserLoaded(current.items, actionError: failure)),
      (_) => emit(UserLoaded(current.items.where((u) => u.id != event.id).toList())),
    );
  }
}
