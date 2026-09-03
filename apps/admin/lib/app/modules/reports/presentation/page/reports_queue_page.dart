import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../domain/entity/report_entities.dart';
import '../bloc/reports_queue_bloc.dart';
import '../bloc/reports_queue_event.dart';
import '../bloc/reports_queue_state.dart';

/// Proactive moderation queue (B3, decision 161): what needs human eyes,
/// in the SERVER's order — tier high → medium → low, media first inside a
/// tier, oldest first. The screen never re-sorts and never filters.
///
/// - Reading the queue is a list read, not audited (166); tapping a row
///   opens the B1 detail, which is.
/// - "Mark reviewed" is ONE human with `reports` UPDATE (165), no reason,
///   audited server-side; the bloc re-fetches — a case leaves the queue
///   only because the server no longer serves it. The API enforces the
///   grant (72); the button merely renders disabled without it.
/// - The future "flag content" signal (161) will enter this same queue
///   above the tier priority — nothing here assumes the order's shape.
class ReportsQueuePage extends StatefulWidget {
  const ReportsQueuePage({super.key, this.autoload = true});

  /// The module route dispatches the load itself when creating the bloc;
  /// a bare page (tests) asks for it here.
  final bool autoload;

  @override
  State<ReportsQueuePage> createState() => _ReportsQueuePageState();
}

class _ReportsQueuePageState extends State<ReportsQueuePage> {
  @override
  void initState() {
    super.initState();
    if (widget.autoload) {
      context.read<ReportsQueueBloc>().add(const ReportsQueueRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return VgrScaffold(
      title: 'reports.queue.title'.tr(),
      body: BlocBuilder<ReportsQueueBloc, ReportsQueueState>(
        builder: (context, state) => switch (state) {
          ReportsQueueInitial() || ReportsQueueLoading() => const VgrLoading(),
          ReportsQueueError(:final failure) =>
            VgrText.error(failureText(failure), key: const Key('queue-error')),
          ReportsQueueLoaded() => VgrScrollView(
              child: VgrColumn(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VgrText.title('reports.queue.header'.plural(state.page.total)),
                  VgrText.caption('reports.queue.hint'.tr()),
                  const VgrGap.md(),
                  if (state.failure != null) ...[
                    VgrText.error(failureText(state.failure!),
                        key: const Key('queue-action-error')),
                    const VgrGap.sm(),
                  ],
                  ..._results(state),
                ],
              ),
            ),
        },
      ),
    );
  }

  List<Widget> _results(ReportsQueueLoaded state) {
    final page = state.page;
    if (page.items.isEmpty) {
      return [VgrText('reports.queue.empty'.tr(), key: const Key('queue-empty'))];
    }
    final canReview = SessionAccess.instance.can('reports', Privileges.update);
    return [
      VgrCard(
        child: VgrColumn(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in page.items) _row(state, entry, canReview: canReview),
          ],
        ),
      ),
      const VgrGap.sm(),
      _pagination(page),
    ];
  }

  Widget _row(ReportsQueueLoaded state, QueueItemEntity entry, {required bool canReview}) {
    final item = entry.item;
    final taxonomy = item.category != null
        ? 'reports.category.${item.category}'.tr()
        : (item.freeTag ?? '—');
    final marks = [
      _age(entry.ageHours),
      if (entry.hasMedia) 'reports.queue.withMedia'.tr(),
      if (item.frozen) 'reports.list.frozenMark'.tr(),
      if (item.anonymous) 'reports.list.anonymousMark'.tr(),
    ];
    return VgrListTile(
      key: Key('queue-row-${item.reportId}'),
      leadingIcon: entry.priority == 'high' ? VgrIconName.alert : VgrIconName.forward,
      title: 'reports.queue.row'.tr(namedArgs: {
        'priority': 'reports.queue.priority.${entry.priority}'.tr(),
        'id': '${item.reportId}',
        'taxonomy': taxonomy,
        'subject': 'reports.subject.${item.subject}'.tr(),
      }),
      subtitle: marks.join(' · '),
      trailing: VgrSecondaryButton(
        key: Key('queue-review-${item.reportId}'),
        label: 'reports.queue.markReviewed'.tr(),
        onPressed: !canReview || state.busy
            ? null
            : () => context
                .read<ReportsQueueBloc>()
                .add(ReportsQueueMarkReviewed(item.reportId)),
      ),
      onTap: () => Modular.to.pushNamed('/reports/${item.reportId}'),
    );
  }

  /// Whole hours under a day, whole days from there ("12 h" / "3 d").
  String _age(int hours) => hours < 24
      ? 'reports.queue.hours'.tr(namedArgs: {'n': '$hours'})
      : 'reports.queue.days'.tr(namedArgs: {'n': '${hours ~/ 24}'});

  Widget _pagination(QueuePageEntity page) {
    final bloc = context.read<ReportsQueueBloc>();
    return VgrRow(
      children: [
        VgrSecondaryButton(
          key: const Key('queue-prev'),
          label: 'reports.list.prev'.tr(),
          onPressed:
              page.page <= 1 ? null : () => bloc.add(ReportsQueuePageRequested(page.page - 1)),
        ),
        const VgrGap.hMd(),
        VgrText('reports.list.pageOf'
            .tr(namedArgs: {'page': '${page.page}', 'pages': '${page.pageCount}'})),
        const VgrGap.hMd(),
        VgrSecondaryButton(
          key: const Key('queue-next'),
          label: 'reports.list.next'.tr(),
          onPressed: page.page >= page.pageCount
              ? null
              : () => bloc.add(ReportsQueuePageRequested(page.page + 1)),
        ),
      ],
    );
  }
}
