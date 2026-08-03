import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/privilege_entity.dart';
import '../../domain/repository/privilege_repository.dart';

sealed class PrivilegeEvent extends Equatable {
  const PrivilegeEvent();

  @override
  List<Object?> get props => [];
}

class PrivilegeFetchRequested extends PrivilegeEvent {
  const PrivilegeFetchRequested();
}

class PrivilegeSaved extends PrivilegeEvent {
  const PrivilegeSaved({this.id, required this.description});

  /// null = create, otherwise update.
  final int? id;
  final String description;

  @override
  List<Object?> get props => [id, description];
}

class PrivilegeDeleted extends PrivilegeEvent {
  const PrivilegeDeleted(this.id);

  final int id;

  @override
  List<Object?> get props => [id];
}

sealed class PrivilegeState extends Equatable {
  const PrivilegeState();

  @override
  List<Object?> get props => [];
}

class PrivilegeLoading extends PrivilegeState {
  const PrivilegeLoading();
}

class PrivilegeLoaded extends PrivilegeState {
  const PrivilegeLoaded(this.items, {this.actionError});

  final List<PrivilegeEntity> items;

  /// Failure of the latest save/delete, kept alongside the list so the page
  /// stays usable (list-preserving error, not a dead end). Carried as
  /// [Failure] so the page translates by code (decisions 80/83).
  final Failure? actionError;

  @override
  List<Object?> get props => [items, actionError];
}

class PrivilegeError extends PrivilegeState {
  const PrivilegeError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class PrivilegeBloc extends Bloc<PrivilegeEvent, PrivilegeState> {
  PrivilegeBloc(this._repository) : super(const PrivilegeLoading()) {
    on<PrivilegeFetchRequested>(_onFetch);
    on<PrivilegeSaved>(_onSaved);
    on<PrivilegeDeleted>(_onDeleted);
  }

  final PrivilegeRepository _repository;

  Future<void> _onFetch(PrivilegeFetchRequested event, Emitter<PrivilegeState> emit) async {
    emit(const PrivilegeLoading());
    final result = await _repository.list();
    result.fold(
      (failure) => emit(PrivilegeError(failure.message)),
      (items) => emit(PrivilegeLoaded(items)),
    );
  }

  Future<void> _onSaved(PrivilegeSaved event, Emitter<PrivilegeState> emit) async {
    final current = state;
    if (current is! PrivilegeLoaded) return;

    final result = event.id == null
        ? await _repository.create(event.description)
        : await _repository.update(event.id!, event.description);

    result.fold(
      (failure) => emit(PrivilegeLoaded(current.items, actionError: failure)),
      (saved) {
        final items = [...current.items.where((p) => p.id != saved.id), saved]
          ..sort((a, b) => a.id.compareTo(b.id));
        emit(PrivilegeLoaded(items));
      },
    );
  }

  Future<void> _onDeleted(PrivilegeDeleted event, Emitter<PrivilegeState> emit) async {
    final current = state;
    if (current is! PrivilegeLoaded) return;

    final result = await _repository.delete(event.id);
    result.fold(
      (failure) => emit(PrivilegeLoaded(current.items, actionError: failure)),
      (_) => emit(PrivilegeLoaded(current.items.where((p) => p.id != event.id).toList())),
    );
  }
}
