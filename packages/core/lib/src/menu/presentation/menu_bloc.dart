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

/// The first shell column: a module was clicked (decision 215). Only the
/// selection changes — no navigation until a screen is picked.
class MenuModuleSelected extends MenuEvent {
  const MenuModuleSelected(this.index);

  final int index;

  @override
  List<Object?> get props => [index];
}

/// A screen was picked (second column / drawer), or the shell matched the
/// current URL to a screen after a refresh. Selects its module too.
class MenuInterfaceSelected extends MenuEvent {
  const MenuInterfaceSelected(this.i18nKey);

  final String i18nKey;

  @override
  List<Object?> get props => [i18nKey];
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
  const MenuLoaded(this.tree, {this.selectedModuleIndex, this.selectedInterfaceKey});

  final List<MenuModule> tree;

  /// Shell selection (decision 215): the module whose screens show in the
  /// second column, and the screen highlighted there. Null until the user
  /// clicks (or the URL is matched on refresh).
  final int? selectedModuleIndex;
  final String? selectedInterfaceKey;

  MenuModule? get selectedModule {
    final index = selectedModuleIndex;
    if (index == null || index < 0 || index >= tree.length) return null;
    return tree[index];
  }

  MenuLoaded copyWith({int? selectedModuleIndex, String? selectedInterfaceKey}) => MenuLoaded(
        tree,
        selectedModuleIndex: selectedModuleIndex ?? this.selectedModuleIndex,
        selectedInterfaceKey: selectedInterfaceKey ?? this.selectedInterfaceKey,
      );

  @override
  List<Object?> get props => [tree, selectedModuleIndex, selectedInterfaceKey];
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
    on<MenuModuleSelected>(_onModuleSelected);
    on<MenuInterfaceSelected>(_onInterfaceSelected);
  }

  void _onModuleSelected(MenuModuleSelected event, Emitter<MenuState> emit) {
    final current = state;
    if (current is! MenuLoaded) return;
    if (event.index < 0 || event.index >= current.tree.length) return;
    emit(current.copyWith(selectedModuleIndex: event.index));
  }

  void _onInterfaceSelected(MenuInterfaceSelected event, Emitter<MenuState> emit) {
    final current = state;
    if (current is! MenuLoaded) return;
    for (var index = 0; index < current.tree.length; index++) {
      final hit = current.tree[index].interfaces.any((i) => i.i18nKey == event.i18nKey);
      if (hit) {
        emit(current.copyWith(selectedModuleIndex: index, selectedInterfaceKey: event.i18nKey));
        return;
      }
    }
    // Unknown key (a route with no menu entry): leave the selection alone.
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
