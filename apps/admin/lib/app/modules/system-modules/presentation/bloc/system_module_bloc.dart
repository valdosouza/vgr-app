import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/system_module_entity.dart';
import '../../domain/repository/system_module_repository.dart';

sealed class SystemModuleEvent extends Equatable {
  const SystemModuleEvent();

  @override
  List<Object?> get props => [];
}

class SystemModuleFetchRequested extends SystemModuleEvent {
  const SystemModuleFetchRequested();
}

class SystemModuleSaved extends SystemModuleEvent {
  const SystemModuleSaved(this.entity);

  /// id 0 = create.
  final SystemModuleEntity entity;

  @override
  List<Object?> get props => [entity];
}

class SystemModuleDeleted extends SystemModuleEvent {
  const SystemModuleDeleted(this.id);

  final int id;

  @override
  List<Object?> get props => [id];
}

sealed class SystemModuleState extends Equatable {
  const SystemModuleState();

  @override
  List<Object?> get props => [];
}

class SystemModuleLoading extends SystemModuleState {
  const SystemModuleLoading();
}

class SystemModuleLoaded extends SystemModuleState {
  const SystemModuleLoaded(this.items, this.interfaceOptions, {this.actionError});

  final List<SystemModuleEntity> items;
  final List<InterfaceOption> interfaceOptions;
  final Failure? actionError;

  @override
  List<Object?> get props => [items, interfaceOptions, actionError];
}

class SystemModuleError extends SystemModuleState {
  const SystemModuleError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class SystemModuleBloc extends Bloc<SystemModuleEvent, SystemModuleState> {
  SystemModuleBloc(this._repository) : super(const SystemModuleLoading()) {
    on<SystemModuleFetchRequested>(_onFetch);
    on<SystemModuleSaved>(_onSaved);
    on<SystemModuleDeleted>(_onDeleted);
  }

  final SystemModuleRepository _repository;

  Future<void> _onFetch(SystemModuleFetchRequested event, Emitter<SystemModuleState> emit) async {
    emit(const SystemModuleLoading());
    final items = await _repository.list();
    final options = await _repository.listInterfaceOptions();

    items.fold(
      (failure) => emit(SystemModuleError(failure.message)),
      (list) => options.fold(
        (failure) => emit(SystemModuleError(failure.message)),
        (opts) => emit(SystemModuleLoaded(list, opts)),
      ),
    );
  }

  Future<void> _onSaved(SystemModuleSaved event, Emitter<SystemModuleState> emit) async {
    final current = state;
    if (current is! SystemModuleLoaded) return;

    final result = event.entity.id == 0
        ? await _repository.create(event.entity)
        : await _repository.update(event.entity);

    result.fold(
      (failure) => emit(SystemModuleLoaded(current.items, current.interfaceOptions, actionError: failure)),
      (saved) {
        final items = [...current.items.where((m) => m.id != saved.id), saved]
          ..sort((a, b) => a.position != b.position
              ? a.position.compareTo(b.position)
              : a.id.compareTo(b.id));
        emit(SystemModuleLoaded(items, current.interfaceOptions));
      },
    );
  }

  Future<void> _onDeleted(SystemModuleDeleted event, Emitter<SystemModuleState> emit) async {
    final current = state;
    if (current is! SystemModuleLoaded) return;

    final result = await _repository.delete(event.id);
    result.fold(
      (failure) => emit(SystemModuleLoaded(current.items, current.interfaceOptions, actionError: failure)),
      (_) => emit(SystemModuleLoaded(
        current.items.where((m) => m.id != event.id).toList(),
        current.interfaceOptions,
      )),
    );
  }
}
