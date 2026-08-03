import 'package:flutter/material.dart';

import 'vgr_icon.dart';
import 'vgr_progress.dart';

/// Encapsulates [ElevatedButton] — the main action of a screen.
///
/// [busy] is part of the contract on purpose: every screen used to
/// hand-roll "spinner instead of label while loading", and each did it
/// slightly differently. Here it is one behavior, defined once.
class VgrPrimaryButton extends StatelessWidget {
  const VgrPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
  });

  final String label;

  /// Null disables the button — the same convention as Flutter's, so
  /// nothing new has to be learned.
  final VoidCallback? onPressed;
  final bool busy;
  final VgrIconName? icon;

  @override
  Widget build(BuildContext context) {
    final child = busy ? const VgrInlineProgress() : Text(label);
    if (icon != null && !busy) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: VgrIcon(icon!),
        label: child,
      );
    }
    return ElevatedButton(onPressed: busy ? null : onPressed, child: child);
  }
}

/// Encapsulates [TextButton] — secondary navigation, links, "cancel".
class VgrTextButton extends StatelessWidget {
  const VgrTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final VgrIconName? icon;

  @override
  Widget build(BuildContext context) => icon == null
      ? TextButton(onPressed: onPressed, child: Text(label))
      : TextButton.icon(onPressed: onPressed, icon: VgrIcon(icon!), label: Text(label));
}

/// Encapsulates [OutlinedButton] — a secondary action with more weight
/// than a text button (retry, alternative path).
class VgrSecondaryButton extends StatelessWidget {
  const VgrSecondaryButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) =>
      OutlinedButton(onPressed: onPressed, child: Text(label));
}

/// Encapsulates [IconButton] — icon-only actions in lists and app bars.
/// [tooltip] is required: an icon with no name is unusable by anyone
/// relying on a screen reader.
class VgrIconButton extends StatelessWidget {
  const VgrIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final VgrIconName icon;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) => IconButton(
        icon: VgrIcon(icon),
        onPressed: onPressed,
        tooltip: tooltip,
      );
}
