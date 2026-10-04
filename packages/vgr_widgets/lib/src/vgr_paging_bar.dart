import 'package:flutter/material.dart';

import 'vgr_button.dart';
import 'vgr_field.dart';
import 'vgr_icon.dart';
import 'vgr_text.dart';

/// The one pager of the panel lists (decision 220 — setes'
/// `RegisterPagingBar`, replacing the prev/next pair each paginated screen
/// used to hand-roll): previous · summary · next, plus the page-size picker
/// when [onPageSizeChanged] is given.
///
/// [summary] arrives translated ("Page 2 of 5 · 93 records") — the design
/// system translates nothing.
class VgrPagingBar extends StatelessWidget {
  const VgrPagingBar({
    super.key,
    required this.page,
    required this.pageCount,
    required this.summary,
    required this.onPageChanged,
    required this.previousTooltip,
    required this.nextTooltip,
    this.pageSize,
    this.pageSizes = const [],
    this.onPageSizeChanged,
    this.pageSizeLabel,
  });

  /// 1-based.
  final int page;
  final int pageCount;
  final String summary;
  final ValueChanged<int> onPageChanged;
  final String previousTooltip;
  final String nextTooltip;

  final int? pageSize;
  final List<int> pageSizes;
  final ValueChanged<int>? onPageSizeChanged;

  /// Text before the size picker ("Per page").
  final String? pageSizeLabel;

  static const previousKey = Key('paging-previous');
  static const nextKey = Key('paging-next');
  static const summaryKey = Key('paging-summary');
  static const pageSizeKey = Key('paging-page-size');

  @override
  Widget build(BuildContext context) => Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          VgrIconButton(
            key: previousKey,
            icon: VgrIconName.back,
            tooltip: previousTooltip,
            onPressed: page > 1 ? () => onPageChanged(page - 1) : null,
          ),
          VgrText(summary, key: summaryKey),
          VgrIconButton(
            key: nextKey,
            icon: VgrIconName.forward,
            tooltip: nextTooltip,
            onPressed: page < pageCount ? () => onPageChanged(page + 1) : null,
          ),
          if (onPageSizeChanged != null && pageSize != null && pageSizes.isNotEmpty) ...[
            if (pageSizeLabel != null) VgrText.caption(pageSizeLabel!),
            VgrDropdown<int>(
              key: pageSizeKey,
              value: pageSize,
              options: [
                for (final size in pageSizes) VgrOption(value: size, label: '$size'),
              ],
              onChanged: onPageSizeChanged,
            ),
          ],
        ],
      );
}
