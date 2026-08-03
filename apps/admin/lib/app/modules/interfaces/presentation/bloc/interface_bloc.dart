import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/interface_entity.dart';
import '../../domain/repository/interface_repository.dart';

sealed class InterfaceEvent extends Equatable {
  const InterfaceEvent();

  @override
  List<Object?> get props => [];
}

class InterfaceFetchRequested extends InterfaceEvent {
  const InterfaceFetchRequested();
}

class InterfaceSaved extends InterfaceEvent {
  const InterfaceSaved(this.entity);

  /// id 0 = create.
  final InterfaceEntity entity;

  @override
  List<Object?> get props => [entity];
}

class InterfaceDeleted extends InterfaceEvent {
  const InterfaceDeleted(this.id);

  final int id;

  @override
  List<Object?> get props => [id];
}

sealed class InterfaceState extends Equatable {
  const InterfaceState();

  @override
  List<Object?> get props => [];
}

class InterfaceLoading extends InterfaceState {
  const InterfaceLoading();
}

class InterfaceLoaded extends InterfaceState {
  const InterfaceLoaded(this.items, this.privilegeOptions, {this.actionError});

  final List<InterfaceEntity> items;
  final List<PrivilegeOption> privilegeOptions;
  final Failure? actionError;

  @override
  List<Object?> get props => [items, privilegeOptions, actionError];
}

class InterfaceError extends InterfaceState {
  const InterfaceError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class InterfaceBloc extends Bloc<InterfaceEvent, InterfaceState> {
  InterfaceBloc(this._repository) : super(const InterfaceLoading()) {
    on<InterfaceFetchRequested>(_onFetch);
    on<InterfaceSaved>(_onSaved);
    on<InterfaceDeleted>(_onDeleted);
  }

  final InterfaceRepository _repository;

  Future<void> _onFetch(InterfaceFetchRequested event, Emitter<InterfaceState> emit) async {
    emit(const InterfaceLoading());
    final items = await _repository.list();
    final options = await _repository.listPrivilegeOptions();

    items.fold(
      (failure) => emit(InterfaceError(failure.message)),
      (list) => options.fold(
        (failure) => emit(InterfaceError(failure.message)),
        (opts) => emit(InterfaceLoaded(list, opts)),
      ),
    );
  }

  Future<void> _onSaved(InterfaceSaved event, Emitter<InterfaceState> emit) async {
    final current = state;
    if (current is! InterfaceLoaded) return;

    final result = event.entity.id == 0
        ? await _repository.create(event.entity)
        : await _repository.update(event.entity);

    result.fold(
      (failure) => emit(InterfaceLoaded(current.items, current.privilegeOptions, actionError: failure)),
      (saved) {
        final items = [...current.items.where((i) => i.id != saved.id), saved]
          ..sort((a, b) => a.groupDefault != b.groupDefault
              ? a.groupDefault.compareTo(b.groupDefault)
              : a.position.compareTo(b.position));
        emit(InterfaceLoaded(items, current.privilegeOptions));
      },
    );
  }

  Future<void> _onDeleted(InterfaceDeleted event, Emitter<InterfaceState> emit) async {
    final current = state;
    if (current is! InterfaceLoaded) return;

    final result = await _repository.delete(event.id);
    result.fold(
      (failure) => emit(InterfaceLoaded(current.items, current.privilegeOptions, actionError: failure)),
      (_) => emit(InterfaceLoaded(
        current.items.where((i) => i.id != event.id).toList(),
        current.privilegeOptions,
      )),
    );
  }
}
