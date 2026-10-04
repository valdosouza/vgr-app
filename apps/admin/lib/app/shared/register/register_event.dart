import 'package:equatable/equatable.dart';

/// Events of the register factory's bloc (decision 217 — setes' `NewPressed`
/// / `EditPressed` / `BackToListPressed` / `SaveRequested` /
/// `DeleteRequested`, plus the list request). Item- and draft-carrying
/// events are generic so the bloc only answers its own entity type.
sealed class RegisterEvent extends Equatable {
  const RegisterEvent();

  @override
  List<Object?> get props => [];
}

/// Loads a page. A null field keeps the current value; a new [filter] or
/// [pageSize] without an explicit [page] goes back to page 1 (the old page
/// number means nothing under a different filter).
final class RegisterListRequested extends RegisterEvent {
  const RegisterListRequested({this.page, this.pageSize, this.filter});

  final int? page;
  final int? pageSize;
  final String? filter;

  @override
  List<Object?> get props => [page, pageSize, filter];
}

final class RegisterNewPressed extends RegisterEvent {
  const RegisterNewPressed();
}

final class RegisterEditPressed<T> extends RegisterEvent {
  const RegisterEditPressed(this.item);

  final T item;

  @override
  List<Object?> get props => [item];
}

/// Leaves the form for the list exactly as it was — no refetch.
final class RegisterBackToListPressed extends RegisterEvent {
  const RegisterBackToListPressed();
}

/// Creates (form opened by "new") or updates (form opened on a row).
final class RegisterSaveRequested<D> extends RegisterEvent {
  const RegisterSaveRequested(this.draft);

  final D draft;

  @override
  List<Object?> get props => [draft];
}

/// Sent only after `askDecision` said yes.
final class RegisterDeleteRequested<T> extends RegisterEvent {
  const RegisterDeleteRequested(this.item);

  final T item;

  @override
  List<Object?> get props => [item];
}
