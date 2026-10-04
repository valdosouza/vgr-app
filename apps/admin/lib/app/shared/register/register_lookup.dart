import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The options a register form offers to pick from — a screen's
/// privileges, a menu module's screens — fetched ONCE when the screen
/// opens, beside the list. The module provides one per lookup at its route
/// and the page feeds its state into a `RegisterChecklistField`
/// (`loading` / `unavailableText` / `options`).
///
/// Only small catalogs belong here: the fetch is the API's unpaged form of
/// the list (decision 220 keeps it for exactly this).
class RegisterLookupCubit<O> extends Cubit<RegisterLookupState<O>> {
  RegisterLookupCubit(this._fetch) : super(RegisterLookupLoading<O>());

  final Future<Either<Failure, List<O>>> Function() _fetch;

  Future<void> load() async {
    emit(RegisterLookupLoading<O>());
    final result = await _fetch();
    if (isClosed) return;
    result.fold(
      (failure) => emit(RegisterLookupFailed<O>(failure)),
      (items) => emit(RegisterLookupLoaded<O>(items)),
    );
  }
}

sealed class RegisterLookupState<O> extends Equatable {
  const RegisterLookupState();

  /// Empty until loaded.
  List<O> get items => const [];

  @override
  List<Object?> get props => [];
}

final class RegisterLookupLoading<O> extends RegisterLookupState<O> {
  const RegisterLookupLoading();
}

final class RegisterLookupLoaded<O> extends RegisterLookupState<O> {
  const RegisterLookupLoaded(this.loaded);

  final List<O> loaded;

  @override
  List<O> get items => loaded;

  @override
  List<Object?> get props => [loaded];
}

final class RegisterLookupFailed<O> extends RegisterLookupState<O> {
  const RegisterLookupFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
