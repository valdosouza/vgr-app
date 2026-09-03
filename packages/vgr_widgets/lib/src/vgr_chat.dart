import 'package:flutter/material.dart';

import 'vgr_icon.dart';

/// Chat widgets of the masked chat (decision 133; used by C2 of the chat
/// front, decisions 54/170/172). The design system knows NOTHING about
/// who is who: a screen hands it the text, the side, the time label as
/// served and a delivery status — identity and masking are the server's
/// and the screen's business, never a widget's.

/// Local delivery status of a bubble (decision 172): a message rides the
/// offline queue, so it is `pending` until the flush confirms and `failed`
/// when the API judged and refused (no retry).
enum VgrChatBubbleStatus { sent, pending, failed }

/// One message. Encapsulates [Align] + [DecoratedBox] + [Text].
class VgrChatBubble extends StatelessWidget {
  const VgrChatBubble({
    super.key,
    required this.text,
    required this.mine,
    required this.timeLabel,
    this.status = VgrChatBubbleStatus.sent,
    this.statusLabel,
  });

  final String text;

  /// True puts the bubble on the right — the value comes from the API's
  /// `mine`, never computed by the screen.
  final bool mine;

  /// Rendered exactly as handed (timestamps arrive already degraded by
  /// tier, decision 174). Empty hides the line.
  final String timeLabel;
  final VgrChatBubbleStatus status;

  /// Already-translated text for a pending/failed marker; ignored when sent.
  final String? statusLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final failed = status == VgrChatBubbleStatus.failed;
    final background = failed
        ? scheme.errorContainer
        : mine
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest;
    final foreground = failed
        ? scheme.onErrorContainer
        : mine
            ? scheme.onPrimaryContainer
            : scheme.onSurface;
    final showStatus = status != VgrChatBubbleStatus.sent && statusLabel != null;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
                  ),
                  if (timeLabel.isNotEmpty || showStatus)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      // Wrap, not Row: a long translated refusal ("Not
                      // sent: direct contact is not allowed (phone: …)")
                      // must break onto the next line, never overflow.
                      child: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (timeLabel.isNotEmpty)
                            Text(
                              timeLabel,
                              style: theme.textTheme.bodySmall?.copyWith(color: foreground),
                            ),
                          if (showStatus)
                            Text(
                              statusLabel!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: failed ? scheme.error : foreground,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The composer: a multi-line [TextField] with a send [IconButton].
/// Enforces [maxLength] at the input (the screen ALSO validates through
/// `vgr_validators` — a cap here only stops the user typing past it).
class VgrChatComposer extends StatelessWidget {
  const VgrChatComposer({
    super.key,
    required this.controller,
    required this.hint,
    required this.sendLabel,
    required this.onSend,
    this.errorText,
    this.maxLength,
    this.enabled = true,
  });

  final TextEditingController controller;

  /// Already-translated hint under the field.
  final String hint;

  /// Tooltip of the send button (required: an icon with no name is
  /// unusable with a screen reader).
  final String sendLabel;

  /// Fired with the current text; the screen validates and enqueues.
  /// Null disables sending — the convention every Vgr widget follows.
  final ValueChanged<String>? onSend;
  final String? errorText;
  final int? maxLength;
  final bool enabled;

  void _send() {
    if (!enabled || onSend == null) return;
    onSend!(controller.text);
  }

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              maxLength: maxLength,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                helperText: hint,
                helperMaxLines: 3,
                errorText: errorText,
                errorMaxLines: 3,
                counterText: '',
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const VgrIcon(VgrIconName.send),
            tooltip: sendLabel,
            onPressed: enabled && onSend != null ? _send : null,
          ),
        ],
      );
}

/// The message column. Encapsulates a [ListView] that starts at the
/// bottom (newest message) — `reverse` keeps the latest visible without
/// the screen animating scrolls; children are handed OLDEST FIRST.
class VgrChatMessageList extends StatelessWidget {
  const VgrChatMessageList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
        reverse: true,
        children: children.reversed.toList(),
      );
}

/// A small count pill — unread messages on a list row. Encapsulates
/// [DecoratedBox] + [Text]; the color comes from the theme.
class VgrBadge extends StatelessWidget {
  const VgrBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onPrimary),
        ),
      ),
    );
  }
}
