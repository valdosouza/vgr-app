import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart' show protected;
import 'package:flutter_bloc/flutter_bloc.dart';

import 'register_event.dart';
import 'register_state.dart';

/// The LIST half of the register factory (decision 220): a paged,
/// filterable list that remembers its query (page, size, filter) and its
/// last loaded page. [RegisterBloc] adds the form on top of it; workflow
/// screens that are not CRUDs (the Legal Gate kill switch, rule approval,
/// the responder queue) extend it directly and add their own row events,
/// run through [act] so every outcome reaches the feedback bridge (221).
///
/// Module events extend [RegisterEvent]; the states are the factory's own.
abstract class PagedListBloc<T> extends Bloc<RegisterEvent, RegisterState<T>> {
  PagedListBloc({PagedQuery initialQuery = const PagedQuery(), RegisterView<T>? initialState})
      : _query = initialQuery,
        super(initialState ?? RegisterListLoading<T>(initialQuery)) {
    on<RegisterListRequested>(_onListRequested);
  }

  PagedQuery _query;
  RegisterListLoaded<T>? _lastList;

  /// The query of the page on screen (or being fetched).
  PagedQuery get query => _query;

  /// The last page that loaded — what "back to the list" returns to.
  @protected
  RegisterListLoaded<T>? get lastList => _lastList;

  /// One page, as the module's repository answers it.
  @protected
  Future<Either<Failure, PagedResult<T>>> fetch(PagedQuery query);

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
    await reload(emit);
  }

  /// Fetches the current query. [quiet] keeps the rows on screen while it
  /// runs (no loading state) — what a row action wants: the list it acted
  /// on stays put and is replaced by the server's answer.
  @protected
  Future<void> reload(Emitter<RegisterState<T>> emit, {bool quiet = false}) async {
    if (!quiet) emit(RegisterListLoading<T>(_query));
    final result = await fetch(_query);
    if (emit.isDone) return;
    await result.fold(
      (failure) async => emit(RegisterListError<T>(_query, failure)),
      (page) async {
        // Past the end — the last row of the last page just went away, or
        // the list shrank under us: land on the real last page instead of
        // an empty one that still claims records exist.
        if (page.items.isEmpty && page.total > 0 && _query.page > page.pageCount) {
          _query = _query.copyWith(page: page.pageCount);
          return reload(emit, quiet: quiet);
        }
        final loaded = RegisterListLoaded<T>(_query, page);
        _lastList = loaded;
        emit(loaded);
      },
    );
  }

  /// Runs a row action and reports it: a failure is signalled, a success
  /// too when [successKey] is given (a translation key), and then the list
  /// is reloaded QUIETLY either way — the server owns the semantics (a
  /// loosening that became pending, a queue row that left), so the screen
  /// shows its answer, not a local guess.
  @protected
  Future<void> act<R>(
    Emitter<RegisterState<T>> emit,
    Future<Either<Failure, R>> Function() action, {
    String? successKey,
  }) async {
    final result = await action();
    if (emit.isDone) return;
    final failure = result.fold((failure) => failure, (_) => null);
    if (failure != null) {
      emit(RegisterActionFailure<T>(failure));
    } else if (successKey != null) {
      emit(RegisterActionSuccess<T>(successKey));
    }
    await reload(emit, quiet: true);
  }
}
