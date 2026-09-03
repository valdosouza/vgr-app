import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vgr_validators/vgr_validators.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../domain/entity/chat_entities.dart';
import '../bloc/chat_conversation_bloc.dart';
import 'chat_threads_page.dart';

/// Who is on the other side, as SERVED: the owner's list hands the
/// participant it received; a helper's own thread has the reporter on the
/// other side by construction of the route (never a name — 170).
class ChatConversationArgs {
  const ChatConversationArgs({required this.otherRole, this.otherName});

  final ChatRole otherRole;
  final String? otherName;
}

/// Text limit of the composer — mirrors `CHAT_MAX_LENGTH` (decisions 171/177).
const chatMaxLength = 1000;

/// One masked conversation (decisions 170-174). Bubbles by the served
/// `mine`, timestamps as served, pending/failed markers from the queue
/// outcome, the API's own anti-contact rule BEFORE anything is enqueued
/// (171), the composer replaced by a notice when the case closed (173).
class ChatConversationPage extends StatefulWidget {
  const ChatConversationPage({
    super.key,
    required this.reportId,
    required this.threadId,
    required this.otherRole,
    this.otherName,
  });

  final int reportId;

  /// Null for a helper's first message — the API creates the thread (173).
  final int? threadId;
  final ChatRole otherRole;
  final String? otherName;

  @override
  State<ChatConversationPage> createState() => _ChatConversationPageState();
}

class _ChatConversationPageState extends State<ChatConversationPage>
    with WidgetsBindingObserver {
  final _composer = TextEditingController();
  String? _composerError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<ChatConversationBloc>().add(ConversationStarted(
          reportId: widget.reportId,
          threadId: widget.threadId,
        ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _composer.dispose();
    super.dispose();
  }

  /// Polling only while the screen is visible (172): pause with the app,
  /// resume with it. Leaving the page closes the bloc, which stops it too.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bloc = context.read<ChatConversationBloc>();
    if (state == AppLifecycleState.resumed) {
      bloc.add(const ConversationResumed());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      bloc.add(const ConversationPaused());
    }
  }

  void _send(String raw) {
    // The API's own rules, mirrored (171/177): required, max length, no
    // direct contact. A hit shows the excerpt under the field and NOTHING
    // is enqueued — a queued message refused hours later helps nobody.
    final errors = VgrValidators.validate({
      'text': (
        raw,
        [
          VgrValidators.required,
          VgrValidators.maxLength(chatMaxLength),
          VgrValidators.noDirectContact,
        ],
      ),
    });
    final error = errors['text'];
    if (error != null) {
      setState(() => _composerError = fieldFailureText(FieldFailure(
            field: 'text',
            message: error.code,
            code: error.code,
            params: error.params,
          )));
      return;
    }
    setState(() => _composerError = null);
    _composer.clear();
    context.read<ChatConversationBloc>().add(ConversationSendPressed(raw.trim()));
  }

  String _statusLabel(ChatMessageEntity message) => switch (message.status) {
        ChatMessageStatus.pending => 'chat.pending'.tr(),
        ChatMessageStatus.failed => 'chat.failed'.tr(namedArgs: {'reason': _reason(message)}),
        ChatMessageStatus.sent => '',
      };

  /// The translated refusal: a field error (`CONTACT_NOT_ALLOWED`) through
  /// `core.fieldErrors`, an envelope code (`CHAT_CLOSED`, `LEGAL_BLOCKED`)
  /// through `core.errors` — the same path any server error takes (80/83).
  String _reason(ChatMessageEntity message) {
    final failure = message.failure;
    if (failure == null) return '';
    final fields = failure.fields;
    if (fields != null && fields.isNotEmpty) return fieldFailureText(fields.first);
    return failureText(failure);
  }

  @override
  Widget build(BuildContext context) {
    return VgrScaffold(
      title: widget.otherName ?? 'chat.role.${widget.otherRole.name}'.tr(),
      body: BlocBuilder<ChatConversationBloc, ChatConversationState>(
        builder: (context, state) => switch (state) {
          ConversationLoading() => const VgrLoading(),
          ConversationError(failure: final failure) => VgrCenter(
              child: VgrColumn(children: [
                VgrText.error(failureText(failure), key: const Key('chat-conversation-error')),
                const VgrGap.md(),
                VgrSecondaryButton(
                  key: const Key('chat-conversation-retry'),
                  label: 'chat.retry'.tr(),
                  onPressed: () => context.read<ChatConversationBloc>().add(
                        ConversationStarted(
                          reportId: widget.reportId,
                          threadId: widget.threadId,
                        ),
                      ),
                ),
              ]),
            ),
          ConversationLoaded() => _loaded(state),
        },
      ),
    );
  }

  Widget _loaded(ConversationLoaded state) {
    return VgrColumn(
      shrink: false,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VgrExpanded(
          child: state.messages.isEmpty
              ? VgrCenter(
                  child: VgrText.caption(
                    'chat.emptyConversation'.tr(),
                    key: const Key('chat-conversation-empty'),
                    align: TextAlign.center,
                  ),
                )
              : VgrChatMessageList(children: [
                  for (final message in state.messages)
                    VgrChatBubble(
                      key: Key('chat-bubble-${message.clientKey}'),
                      text: message.purged ? 'chat.purged'.tr() : (message.text ?? ''),
                      mine: message.mine,
                      timeLabel: message.status == ChatMessageStatus.sent
                          ? formatChatTime(message.createdAt)
                          : '',
                      status: switch (message.status) {
                        ChatMessageStatus.sent => VgrChatBubbleStatus.sent,
                        ChatMessageStatus.pending => VgrChatBubbleStatus.pending,
                        ChatMessageStatus.failed => VgrChatBubbleStatus.failed,
                      },
                      statusLabel: _statusLabel(message),
                    ),
                ]),
        ),
        const VgrGap.sm(),
        if (state.closed)
          VgrCard(
            child: VgrPadding(
              child: VgrText.caption(
                'chat.closedNotice'.tr(),
                key: const Key('chat-closed-notice'),
              ),
            ),
          )
        else
          VgrChatComposer(
            key: const Key('chat-composer'),
            controller: _composer,
            hint: 'chat.composerHint'.tr(),
            sendLabel: 'chat.send'.tr(),
            errorText: _composerError,
            maxLength: chatMaxLength,
            onSend: _send,
          ),
      ],
    );
  }
}
