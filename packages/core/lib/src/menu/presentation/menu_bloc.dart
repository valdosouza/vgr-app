import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/menu_entity.dart';
import '../domain/menu_repository.dart';
import '../session_access.dart';

sealed class MenuEvent extends Equatable {
  const MenuEvent();

  @override
  List<Object?> get props => [];
}

class MenuRequested extends MenuEvent {
  const MenuRequested();
}

sealed class MenuState extends Equatable {
  const MenuState();

  @override
  List<Object?> get props => [];
}

class MenuLoading extends MenuState {
  const MenuLoading();
}

class MenuLoaded extends MenuState {
  const MenuLoaded(this.tree);

  final List<MenuModule> tree;

  @override
  List<Object?> get props => [tree];
}

class MenuError extends MenuState {
  const MenuError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class MenuBloc extends Bloc<MenuEvent, MenuState> {
  MenuBloc(this._repository) : super(const MenuLoading()) {
    on<MenuRequested>(_onRequested);
  }

  final MenuRepository _repository;

  Future<void> _onRequested(MenuRequested event, Emitter<MenuState> emit) async {
    emit(const MenuLoading());
    // Fired together, awaited typed.
    final menusFuture = _repository.getMenus();
    final permissionsFuture = _repository.getPermissions();
    final menusResult = await menusFuture;
    final permissionsResult = await permissionsFuture;

    menusResult.fold(
      (failure) => emit(MenuError(failure.message)),
      (tree) {
        // Feeds the UX-only can() lookup used by every screen's buttons.
        // Preferred source is the full permissions map (includes kind 'R'
        // resources — decision 93); the tree is the degraded fallback.
        permissionsResult.fold(
          (_) => SessionAccess.instance.apply(tree),
          (map) => SessionAccess.instance.applyPermissions(map),
        );
        emit(MenuLoaded(tree));
      },
    );
  }
}
