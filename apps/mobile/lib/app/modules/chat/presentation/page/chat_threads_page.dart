import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../domain/entity/chat_entities.dart';
import '../bloc/chat_threads_bloc.dart';
import 'chat_conversation_page.dart';

/// The owner's conversations, one row per helper (decisions 55/170). Every
/// row renders the OTHER participant exactly as served: the role label,
/// or the display name when the API sent one. Nothing is inferred here.
class ChatThreadsPage extends StatefulWidget {
  const ChatThreadsPage({super.key, required this.reportId, this.onOpenThread});

  final int reportId;

  /// Test seam — default navigation goes through Modular.
  final void Function(ChatThreadSummaryEntity thread)? onOpenThread;

  @override
  State<ChatThreadsPage> createState() => _ChatThreadsPageState();
}

class _ChatThreadsPageState extends State<ChatThreadsPage> {
  @override
  void initState() {
    super.initState();
    context.read<ChatThreadsBloc>().add(ThreadsStarted(widget.reportId));
  }

  void _open(ChatThreadSummaryEntity thread) {
    if (widget.onOpenThread != null) {
      widget.onOpenThread!(thread);
      return;
    }
    Modular.to.pushNamed(
      '/chat/${widget.reportId}/thread/${thread.threadId}',
      arguments: ChatConversationArgs(
        otherRole: thread.other.role,
        otherName: thread.other.displayName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VgrScaffold(
      title: 'chat.threadsTitle'.tr(),
      padded: false,
      body: BlocBuilder<ChatThreadsBloc, ChatThreadsState>(
        builder: (context, state) => switch (state) {
          ThreadsLoading() => const VgrLoading(),
          ThreadsError(failure: final failure) => VgrCenter(
              child: VgrColumn(children: [
                VgrText.error(failureText(failure), key: const Key('chat-threads-error')),
                const VgrGap.md(),
                VgrSecondaryButton(
                  key: const Key('chat-threads-retry'),
                  label: 'chat.retry'.tr(),
                  onPressed: () =>
                      context.read<ChatThreadsBloc>().add(ThreadsStarted(widget.reportId)),
                ),
              ]),
            ),
          ThreadsLoaded(threads: final threads) => threads.isEmpty
              ? VgrCenter(
                  child: VgrText.caption('chat.empty'.tr(), key: const Key('chat-threads-empty')),
                )
              : VgrListView(children: [
                  for (final thread in threads)
                    VgrListTile(
                      key: Key('chat-thread-${thread.threadId}'),
                      leadingIcon: VgrIconName.person,
                      title: participantLabel(thread.other),
                      subtitle: thread.lastMessageAt == null
                          ? 'chat.noMessages'.tr()
                          : formatChatTime(thread.lastMessageAt!),
                      trailing: VgrRow(children: [
                        if (thread.closed)
                          VgrText.caption(
                            'chat.closedMarker'.tr(),
                            key: Key('chat-thread-${thread.threadId}-closed'),
                          ),
                        if (thread.closed && thread.unreadCount > 0) const VgrGap.hSm(),
                        if (thread.unreadCount > 0)
                          VgrBadge(
                            key: Key('chat-thread-${thread.threadId}-unread'),
                            label: '${thread.unreadCount}',
                          ),
                      ]),
                      onTap: () => _open(thread),
                    ),
                ]),
        },
      ),
    );
  }
}

/// The served display name when there is one, else the fixed role label
/// (decision 170). Shared by both chat pages.
String participantLabel(ChatParticipantEntity participant) =>
    participant.displayName ?? 'chat.role.${participant.role.name}'.tr();

/// Timestamps are rendered as served — already degraded by tier (174).
String formatChatTime(String iso) =>
    iso.length >= 16 ? iso.replaceFirst('T', ' ').substring(0, 16) : iso;
