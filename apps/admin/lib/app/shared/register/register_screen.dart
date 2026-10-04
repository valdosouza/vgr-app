import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../feedback/feedback.dart';
import '../session/current_interface.dart';
import 'register_bloc.dart';
import 'register_field.dart';
import 'paged_list_screen.dart';
import 'register_form_page.dart';
import 'register_search_page.dart';

/// The register FACTORY (PS2 — decisions 217/220/221): a simple CRUD
/// screen of the panel is this widget plus its configuration. It wires,
/// once for every screen:
///
/// - list ↔ form by the bloc's STATE on one route (217);
/// - the "new" button, save and delete by the screen's privileges
///   ([CurrentInterface] — INSERT / UPDATE / DELETE); a row opens the form
///   even without UPDATE, read-only, so the record can still be read;
/// - deletion only after `askDecision`;
/// - every outcome through the feedback bridge (221): server field errors
///   anchored on their field first, everything else by severity.
///
/// The bloc is looked up as `RegisterBloc<T, D>` — modules declare theirs
/// as a type alias of it so the provider matches (a subclass with row
/// actions is provided under that base type).
///
/// [openRows] false keeps rows closed: a register whose records are never
/// edited, only added (a Legal Gate rule is versioned — a change is a new
/// proposal, decision 107).
class RegisterScreen<T, D> extends StatefulWidget {
  const RegisterScreen({
    super.key,
    required this.title,
    required this.screen,
    required this.rowBuilder,
    required this.rowId,
    required this.formTitle,
    required this.fields,
    required this.draftOf,
    this.actions = const [],
    this.openRows = true,
  });

  final String title;
  final CurrentInterface screen;
  final RegisterRow Function(BuildContext context, T item) rowBuilder;
  final Object Function(T item) rowId;

  /// Title of the form; [current] null = a new record.
  final String Function(T? current) formTitle;
  final List<RegisterField> Function(T? current) fields;
  final D Function(T? current, RegisterValues values) draftOf;

  /// List header actions.
  final List<Widget> actions;

  final bool openRows;

  @override
  State<RegisterScreen<T, D>> createState() => _RegisterScreenState<T, D>();
}

class _RegisterScreenState<T, D> extends State<RegisterScreen<T, D>> {
  final _form = GlobalKey<RegisterFormPageState>();

  RegisterBloc<T, D> get _bloc => context.read<RegisterBloc<T, D>>();

  void _onSignal(BuildContext context, RegisterState<T> state) => showRegisterSignal<T>(
        context,
        state,
        anchor: (failure) => _form.currentState?.showServerFieldError(failure) ?? false,
      );

  Future<void> _confirmDelete(T item) async {
    final decision = await askDecision(
      context,
      title: 'register.confirmDeleteTitle'.tr(),
      message: 'register.confirmDeleteMessage'.tr(),
      yesLabel: 'register.delete'.tr(),
      destructive: true,
    );
    if (decision == Decision.yes && mounted) _bloc.add(RegisterDeleteRequested<T>(item));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RegisterBloc<T, D>, RegisterState<T>>(
      listenWhen: (_, state) => state is RegisterSignal<T>,
      listener: _onSignal,
      buildWhen: (_, state) => state is RegisterView<T>,
      builder: (context, state) => switch (state) {
        RegisterListLoading<T>(:final query) => _list(filter: query.filter),
        RegisterListLoaded<T>(:final query, :final page) => _list(filter: query.filter, page: page),
        RegisterListError<T>(:final query, :final failure) =>
          _list(filter: query.filter, failure: failure),
        RegisterFormState<T>(:final current, :final busy) => _formOf(current, busy: busy),
        // Unreachable: buildWhen lets only views through, and the bloc
        // starts on (and always returns to) a view.
        RegisterSignal<T>() => const VgrLoading(),
      },
    );
  }

  Widget _list({required String filter, PagedResult<T>? page, Failure? failure}) {
    return RegisterSearchPage<T>(
      title: widget.title,
      actions: widget.actions,
      filter: filter,
      page: page,
      failure: failure,
      rowBuilder: widget.rowBuilder,
      rowId: widget.rowId,
      onFilter: (text) => _bloc.add(RegisterListRequested(filter: text)),
      onRetry: () => _bloc.add(const RegisterListRequested()),
      onOpen: widget.openRows ? (item) => _bloc.add(RegisterEditPressed<T>(item)) : null,
      onNew: widget.screen.canInsert ? () => _bloc.add(const RegisterNewPressed()) : null,
      onPageChanged: (number) => _bloc.add(RegisterListRequested(page: number)),
      onPageSizeChanged: (size) => _bloc.add(RegisterListRequested(pageSize: size)),
    );
  }

  Widget _formOf(T? current, {required bool busy}) {
    final canSave = current == null ? widget.screen.canInsert : widget.screen.canUpdate;
    return RegisterFormPage(
      key: _form,
      title: widget.formTitle(current),
      fields: widget.fields(current),
      busy: busy,
      onBack: () => _bloc.add(const RegisterBackToListPressed()),
      onSave: canSave
          ? (values) => _bloc.add(RegisterSaveRequested<D>(widget.draftOf(current, values)))
          : null,
      onDelete: current != null && widget.screen.canDelete ? () => _confirmDelete(current) : null,
    );
  }
}
