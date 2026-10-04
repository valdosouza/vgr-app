import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../feedback/feedback.dart';
import 'paged_list_bloc.dart';
import 'register_event.dart';
import 'register_search_page.dart';
import 'register_state.dart';

/// Hands a factory signal to the feedback bridge (decision 221): success
/// as a transient message, failure by severity. [anchor] gets the first
/// try at a failure (a form placing `fields[]` on its fields) and answers
/// whether it did.
void showRegisterSignal<T>(
  BuildContext context,
  RegisterState<T> state, {
  bool Function(Failure failure)? anchor,
}) {
  switch (state) {
    case RegisterActionSuccess<T>(:final messageKey):
      showSuccessFeedback(context, messageKey.tr());
    case RegisterActionFailure<T>(:final failure):
      if (!(anchor?.call(failure) ?? false)) showFailureFeedback(context, failure);
    default:
      break;
  }
}

/// A paged list WITHOUT the register form (decision 220 on the workflow
/// screens): filter, rows, pager, empty state and the bridge — the rows
/// carry the workflow's own controls (`RegisterRow.subtitleWidget` /
/// `trailing`), which send the bloc's own events. [B] is the module's
/// [PagedListBloc] subclass, provided by the route under its own type.
class PagedListScreen<T, B extends PagedListBloc<T>> extends StatelessWidget {
  const PagedListScreen({
    super.key,
    required this.title,
    required this.rowBuilder,
    required this.rowId,
    this.actions = const [],
    this.header,
    this.filterable = true,
    this.emptyMessage,
  });

  final String title;
  final RegisterRow Function(BuildContext context, T item) rowBuilder;
  final Object Function(T item) rowId;
  final List<Widget> actions;
  final Widget? header;
  final bool filterable;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<B, RegisterState<T>>(
      listenWhen: (_, state) => state is RegisterSignal<T>,
      listener: (context, state) => showRegisterSignal<T>(context, state),
      buildWhen: (_, state) => state is RegisterView<T>,
      builder: (context, state) {
        final bloc = context.read<B>();
        PagedResult<T>? page;
        Failure? failure;
        var filter = bloc.query.filter;
        switch (state) {
          case RegisterListLoaded<T>(:final query, page: final loaded):
            page = loaded;
            filter = query.filter;
          case RegisterListError<T>(:final query, failure: final error):
            failure = error;
            filter = query.filter;
          case RegisterListLoading<T>(:final query):
            filter = query.filter;
          // A plain list has no form; signals never reach the builder.
          case RegisterFormState<T>() || RegisterSignal<T>():
            break;
        }
        return RegisterSearchPage<T>(
          title: title,
          actions: actions,
          header: header,
          filterable: filterable,
          emptyMessage: emptyMessage,
          filter: filter,
          page: page,
          failure: failure,
          rowBuilder: rowBuilder,
          rowId: rowId,
          onFilter: (text) => bloc.add(RegisterListRequested(filter: text)),
          onRetry: () => bloc.add(const RegisterListRequested()),
          onPageChanged: (number) => bloc.add(RegisterListRequested(page: number)),
          onPageSizeChanged: (size) => bloc.add(RegisterListRequested(pageSize: size)),
        );
      },
    );
  }
}
