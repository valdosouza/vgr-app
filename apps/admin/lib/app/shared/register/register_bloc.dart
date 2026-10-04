import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'register_event.dart';
import 'register_repository.dart';
import 'register_state.dart';

export 'register_event.dart';
export 'register_repository.dart';
export 'register_state.dart';

/// The bloc of every simple register screen (decision 217): ONE bloc that
/// alternates list ↔ form by STATE, on one route — the URL never changes
/// between them. A module declares its own as a type alias
/// (`typedef PrivilegeBloc = RegisterBloc<PrivilegeEntity, PrivilegeDraft>`),
/// so the provider type and `RegisterScreen`'s lookup are the same type.
///
/// Remembers the query (page, size, filter) and the last loaded page, so
/// "back to the list" returns to exactly what was there, and a save or a
/// delete refreshes that same page.
class RegisterBloc<T, D> extends Bloc<RegisterEvent, RegisterState<T>> {
  RegisterBloc(this._repository, {PagedQuery initialQuery = const PagedQuery()})
      : _query = initialQuery,
        super(RegisterListLoading<T>(initialQuery)) {
    on<RegisterListRequested>(_onListRequested);
    on<RegisterNewPressed>(_onNewPressed);
    on<RegisterEditPressed<T>>(_onEditPressed);
    on<RegisterBackToListPressed>(_onBackToList);
    on<RegisterSaveRequested<D>>(_onSaveRequested);
    on<RegisterDeleteRequested<T>>(_onDeleteRequested);
  }

  final RegisterRepository<T, D> _repository;
  PagedQuery _query;
  RegisterListLoaded<T>? _lastList;

  static const savedKey = 'register.saved';
  static const deletedKey = 'register.deleted';

  Future<void> _onListRequested(
    RegisterListRequested event,
    Emitter<RegisterState<T>> emit,
  ) async {
    final backToFirst = event.page == null && (event.filter != null || event.pageSize != null);
    _query = _query.copyWith(
      page: event.page ?? (backToFirst ? 1 : null),
      pageSize: event.pageSize,
      filter: event.filter,
    );
    await _load(emit);
  }

  Future<void> _load(Emitter<RegisterState<T>> emit) async {
    emit(RegisterListLoading<T>(_query));
    final result = await _repository.list(_query);
    await result.fold(
      (failure) async => emit(RegisterListError<T>(_query, failure)),
      (page) async {
        // Past the end — the last row of the last page was just deleted,
        // or the list shrank under us: land on the real last page instead
        // of an empty one that still claims records exist.
        if (page.items.isEmpty && page.total > 0 && _query.page > page.pageCount) {
          _query = _query.copyWith(page: page.pageCount);
          return _load(emit);
        }
        final loaded = RegisterListLoaded<T>(_query, page);
        _lastList = loaded;
        emit(loaded);
      },
    );
  }

  void _onNewPressed(RegisterNewPressed event, Emitter<RegisterState<T>> emit) {
    emit(RegisterFormState<T>(null));
  }

  void _onEditPressed(RegisterEditPressed<T> event, Emitter<RegisterState<T>> emit) {
    emit(RegisterFormState<T>(event.item));
  }

  Future<void> _onBackToList(
    RegisterBackToListPressed event,
    Emitter<RegisterState<T>> emit,
  ) async {
    final current = state;
    // Leaving mid-save would show a list the save is about to change.
    if (current is RegisterFormState<T> && current.busy) return;
    final last = _lastList;
    if (last != null) {
      emit(last);
    } else {
      await _load(emit);
    }
  }

  Future<void> _onSaveRequested(
    RegisterSaveRequested<D> event,
    Emitter<RegisterState<T>> emit,
  ) async {
    final form = state;
    if (form is! RegisterFormState<T> || form.busy) return;

    emit(RegisterFormState<T>(form.current, busy: true));
    final editing = form.current;
    final result = editing == null
        ? await _repository.create(event.draft)
        : await _repository.update(editing, event.draft);

    final failure = result.fold((failure) => failure, (_) => null);
    if (failure != null) {
      emit(RegisterActionFailure<T>(failure));
      emit(RegisterFormState<T>(editing));
      return;
    }
    emit(RegisterActionSuccess<T>(savedKey));
    await _load(emit);
  }

  Future<void> _onDeleteRequested(
    RegisterDeleteRequested<T> event,
    Emitter<RegisterState<T>> emit,
  ) async {
    final before = state;
    if (before is! RegisterView<T>) return;
    if (before is RegisterFormState<T>) {
      if (before.busy) return;
      emit(RegisterFormState<T>(before.current, busy: true));
    }

    final result = await _repository.delete(event.item);
    final failure = result.fold((failure) => failure, (_) => null);
    if (failure != null) {
      emit(RegisterActionFailure<T>(failure));
      emit(before);
      return;
    }
    emit(RegisterActionSuccess<T>(deletedKey));
    await _load(emit);
  }
}
