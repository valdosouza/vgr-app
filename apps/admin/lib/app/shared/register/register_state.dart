import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

/// States of the register factory's bloc (decision 217). Two families:
///
/// - [RegisterView] — BUILDABLE: what the screen draws (the list in one of
///   its three moments, or the form). Only these reach the builder.
/// - [RegisterSignal] — ONE-SHOT: an action's outcome, consumed only by
///   the listener (feedback). The bloc always emits a view right after a
///   signal, so `bloc.state` is a view between events.
sealed class RegisterState<T> extends Equatable {
  const RegisterState();
}

sealed class RegisterView<T> extends RegisterState<T> {
  const RegisterView();
}

final class RegisterListLoading<T> extends RegisterView<T> {
  const RegisterListLoading(this.query);

  final PagedQuery query;

  @override
  List<Object?> get props => [query];
}

final class RegisterListLoaded<T> extends RegisterView<T> {
  const RegisterListLoaded(this.query, this.page);

  final PagedQuery query;
  final PagedResult<T> page;

  @override
  List<Object?> get props => [query, page];
}

final class RegisterListError<T> extends RegisterView<T> {
  const RegisterListError(this.query, this.failure);

  final PagedQuery query;
  final Failure failure;

  @override
  List<Object?> get props => [query, failure];
}

/// The form, on [current] (null = a new record). [busy] while a save or a
/// delete is in flight.
final class RegisterFormState<T> extends RegisterView<T> {
  const RegisterFormState(this.current, {this.busy = false});

  final T? current;
  final bool busy;

  bool get isNew => current == null;

  @override
  List<Object?> get props => [current, busy];
}

sealed class RegisterSignal<T> extends RegisterState<T> {
  const RegisterSignal();
}

/// [messageKey] is a translation key — the bloc never holds UI text.
final class RegisterActionSuccess<T> extends RegisterSignal<T> {
  const RegisterActionSuccess(this.messageKey);

  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

final class RegisterActionFailure<T> extends RegisterSignal<T> {
  const RegisterActionFailure(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
