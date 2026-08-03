import 'package:flutter/material.dart';

import 'vgr_layout.dart';

/// Encapsulates [Scaffold] + [AppBar] (decision 133).
///
/// One widget instead of two because every screen in the panel pairs them
/// the same way; keeping them together removes the chance of a screen
/// inventing its own header.
class VgrScaffold extends StatelessWidget {
  const VgrScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.padded = true,
    this.floatingAction,
  });

  final String title;
  final Widget body;

  /// App-bar actions — already-built Vgr widgets, never raw ones.
  final List<Widget> actions;

  /// Screen padding on by default: forms with no padding were the most
  /// repeated mistake before this existed.
  final bool padded;
  final Widget? floatingAction;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: padded ? VgrPadding.screen(child: body) : body,
        floatingActionButton: floatingAction,
      );
}

/// Encapsulates [FloatingActionButton] — the "create" affordance on list
/// screens. [tooltip] is required for the same reason as on icon buttons.
class VgrFloatingAddButton extends StatelessWidget {
  const VgrFloatingAddButton({super.key, required this.onPressed, required this.tooltip});

  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) => FloatingActionButton(
        onPressed: onPressed,
        tooltip: tooltip,
        child: const Icon(Icons.add),
      );
}
