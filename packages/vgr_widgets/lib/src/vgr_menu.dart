import 'package:flutter/material.dart';

import 'vgr_icon.dart';

/// One entry of a [VgrMenuButton].
class VgrMenuEntry<T> {
  const VgrMenuEntry({
    required this.value,
    required this.label,
    this.selected = false,
    this.key,
  });

  final T value;
  final String label;

  /// Renders a check mark and keeps the alignment of the other entries —
  /// the reason this is a design-system concern and not a screen one.
  final bool selected;
  final Key? key;
}

/// Encapsulates [PopupMenuButton] (decision 133).
class VgrMenuButton<T> extends StatelessWidget {
  const VgrMenuButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.entriesBuilder,
    required this.onSelected,
  });

  final VgrIconName icon;
  final String tooltip;

  /// A BUILDER, not a list: entries are resolved when the menu opens, the
  /// same laziness [PopupMenuButton] has. Building them eagerly would drag
  /// whatever the entries depend on — the current locale, a bloc state —
  /// into the parent's build, which is a behavior change, not a detail.
  final List<VgrMenuEntry<T>> Function(BuildContext context) entriesBuilder;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<T>(
        icon: VgrIcon(icon),
        tooltip: tooltip,
        onSelected: onSelected,
        itemBuilder: (menuContext) => [
          for (final entry in entriesBuilder(menuContext))
            PopupMenuItem<T>(
              key: entry.key,
              value: entry.value,
              child: Row(
                children: [
                  if (entry.selected)
                    const VgrIcon(VgrIconName.check, size: 16)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  Text(entry.label),
                ],
              ),
            ),
        ],
      );
}
