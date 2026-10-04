import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

/// What one list row shows — the factory builds the tile, so every list
/// taps, keys and spaces its rows the same way.
class RegisterRow {
  const RegisterRow({
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.leadingIcon,
    this.trailing,
  });

  final String title;
  final String? subtitle;

  /// A second line that holds controls rather than text — the kill-switch
  /// state picker, a rule's approve/reject. Wins over [subtitle].
  final Widget? subtitleWidget;
  final VgrIconName? leadingIcon;

  /// Row actions beyond "open" (the user's privilege matrix, for one).
  final Widget? trailing;
}

/// The register list (setes' `RegisterSearchPage`): filter on top, rows,
/// the empty state, the pager at the foot (decision 220) and the "new"
/// button when the user may insert. Purely presentational — it draws one
/// of three moments (loading / [failure] / [page]) and reports intents.
class RegisterSearchPage<T> extends StatefulWidget {
  const RegisterSearchPage({
    super.key,
    required this.title,
    required this.filter,
    required this.onFilter,
    required this.rowBuilder,
    required this.rowId,
    this.page,
    this.failure,
    this.onRetry,
    this.onOpen,
    this.onNew,
    this.onPageChanged,
    this.onPageSizeChanged,
    this.actions = const [],
    this.header,
    this.filterable = true,
    this.emptyMessage,
  });

  final String title;

  /// The filter the shown page was fetched with.
  final String filter;
  final ValueChanged<String> onFilter;

  final RegisterRow Function(BuildContext context, T item) rowBuilder;

  /// Stable id of a row — its key is `register-row-<id>`.
  final Object Function(T item) rowId;

  /// Null with a null [failure] = still loading.
  final PagedResult<T>? page;
  final Failure? failure;
  final VoidCallback? onRetry;

  final ValueChanged<T>? onOpen;

  /// Null = no "new" button (no INSERT on this screen).
  final VoidCallback? onNew;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<int>? onPageSizeChanged;

  /// Header actions beside the title.
  final List<Widget> actions;

  /// Above the filter — a parameter the list cannot be fetched without
  /// (the jurisdiction of the capability overview).
  final Widget? header;

  /// False hides the filter: the resource has no text to match (the
  /// responder queue carries no name — PS0).
  final bool filterable;

  /// Replaces the generic empty wording — a list that waits for a
  /// parameter says which.
  final String? emptyMessage;

  static const newButtonKey = Key('register-new-button');
  static const emptyKey = Key('register-empty');
  static const errorKey = Key('register-error');
  static const retryKey = Key('register-retry');

  static Key rowKey(Object id) => Key('register-row-$id');

  @override
  State<RegisterSearchPage<T>> createState() => _RegisterSearchPageState<T>();
}

class _RegisterSearchPageState<T> extends State<RegisterSearchPage<T>> {
  late final _filter = TextEditingController(text: widget.filter);

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = widget.page;
    return VgrPage(
      title: widget.title,
      actions: widget.actions,
      padded: false,
      floatingAction: widget.onNew == null
          ? null
          : VgrFloatingAddButton(
              key: RegisterSearchPage.newButtonKey,
              tooltip: 'register.new'.tr(),
              onPressed: widget.onNew!,
            ),
      body: VgrColumn(
        shrink: false,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.header != null) VgrPadding(child: widget.header!),
          if (widget.filterable)
            VgrPadding(
              child: VgrSearchBar(
                controller: _filter,
                label: 'register.search'.tr(),
                searchTooltip: 'register.search'.tr(),
                onSubmitted: widget.onFilter,
              ),
            ),
          VgrExpanded(child: _content(context)),
          if (page != null && page.total > 0)
            VgrPadding(
              all: 8,
              child: VgrPagingBar(
                page: page.page,
                pageCount: page.pageCount,
                summary: 'register.pageSummary'.tr(namedArgs: {
                  'page': '${page.page}',
                  'pages': '${page.pageCount}',
                  'total': '${page.total}',
                }),
                onPageChanged: widget.onPageChanged ?? (_) {},
                previousTooltip: 'register.previousPage'.tr(),
                nextTooltip: 'register.nextPage'.tr(),
                pageSize: page.pageSize,
                pageSizes: PagedQuery.pageSizes,
                onPageSizeChanged: widget.onPageSizeChanged,
                pageSizeLabel: 'register.pageSize'.tr(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context) {
    final failure = widget.failure;
    if (failure != null) {
      return VgrCenter(
        child: VgrColumn(
          children: [
            VgrText.error(failureText(failure), key: RegisterSearchPage.errorKey),
            if (widget.onRetry != null) ...[
              const VgrGap.md(),
              VgrSecondaryButton(
                key: RegisterSearchPage.retryKey,
                label: 'register.retry'.tr(),
                onPressed: widget.onRetry,
              ),
            ],
          ],
        ),
      );
    }

    final page = widget.page;
    if (page == null) return const VgrLoading();
    if (page.items.isEmpty) {
      return VgrEmptyState(
        key: RegisterSearchPage.emptyKey,
        message: widget.emptyMessage ??
            (widget.filter.trim().isEmpty ? 'register.empty'.tr() : 'register.emptyFiltered'.tr()),
      );
    }

    return VgrListView(
      children: [
        for (final item in page.items) _row(context, item),
      ],
    );
  }

  Widget _row(BuildContext context, T item) {
    final row = widget.rowBuilder(context, item);
    final onOpen = widget.onOpen;
    return VgrListTile(
      key: RegisterSearchPage.rowKey(widget.rowId(item)),
      title: row.title,
      subtitle: row.subtitle,
      subtitleWidget: row.subtitleWidget,
      leadingIcon: row.leadingIcon,
      trailing: row.trailing,
      onTap: onOpen == null ? null : () => onOpen(item),
    );
  }
}
