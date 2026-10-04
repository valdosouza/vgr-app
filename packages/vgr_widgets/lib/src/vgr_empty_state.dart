import 'package:flutter/material.dart';

import 'vgr_icon.dart';
import 'vgr_text.dart';

/// What a list shows when it has nothing to show — one look for every
/// screen instead of a bare line of text in each.
class VgrEmptyState extends StatelessWidget {
  const VgrEmptyState({super.key, required this.message, this.icon = VgrIconName.search});

  final String message;
  final VgrIconName icon;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VgrIcon(icon, size: 40, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 8),
              VgrText.caption(message, align: TextAlign.center),
            ],
          ),
        ),
      );
}
