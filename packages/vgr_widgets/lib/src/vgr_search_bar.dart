import 'package:flutter/material.dart';

import 'vgr_icon.dart';

/// The filter field on top of a register list (setes' search page): Enter
/// or the magnifier submits the typed text. Submitting is explicit — the
/// list never refetches per keystroke.
class VgrSearchBar extends StatelessWidget {
  const VgrSearchBar({
    super.key,
    required this.controller,
    required this.label,
    required this.searchTooltip,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String searchTooltip;

  /// Receives the field's current text, untrimmed — trimming is the
  /// query's job, the same rule the API applies.
  final ValueChanged<String> onSubmitted;

  static const fieldKey = Key('search-bar-field');
  static const buttonKey = Key('search-bar-button');

  @override
  Widget build(BuildContext context) => TextField(
        key: fieldKey,
        controller: controller,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: IconButton(
            key: buttonKey,
            icon: const VgrIcon(VgrIconName.search),
            tooltip: searchTooltip,
            onPressed: () => onSubmitted(controller.text),
          ),
        ),
      );
}
