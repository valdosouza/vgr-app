import 'package:flutter/material.dart';

/// Building blocks of the admin shell (decision 215 — two navigation
/// columns beside the content, the setes-app layout).

/// One vertical navigation column: a fixed width, a tinted surface and a
/// scrolling list of tiles. [level] picks the tint — 0 for the first
/// column (modules), 1 for the second (screens of the selected module) —
/// so the two read as nested without any screen choosing colors.
class VgrNavColumn extends StatelessWidget {
  const VgrNavColumn({
    super.key,
    required this.children,
    this.width = 200,
    this.level = 0,
  });

  final List<Widget> children;
  final double width;
  final int level;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Material(
        color: level == 0 ? scheme.surfaceContainerHighest : scheme.surfaceContainerHigh,
        child: ListView(children: children),
      ),
    );
  }
}

/// The shell body: navigation columns on the left, the content filling
/// the rest, everything stretched to the full height.
///
/// The content is its own semantics container: in the panel it is a nested
/// Navigator (the shell's `RouterOutlet`), and every route of a Navigator
/// paints a `ModalBarrier` whose `BlockSemantics` drops the semantics of
/// whatever was painted before it in the same container — the navigation
/// columns. Without the boundary the whole menu was invisible to screen
/// readers (found in the browser test of 2026-10-04).
class VgrSidebarLayout extends StatelessWidget {
  const VgrSidebarLayout({super.key, required this.sidebars, required this.content});

  final List<Widget> sidebars;
  final Widget content;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...sidebars,
          Expanded(child: Semantics(container: true, child: content)),
        ],
      );
}

/// Encapsulates [Drawer] — the mobile form of the shell navigation.
class VgrDrawer extends StatelessWidget {
  const VgrDrawer({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Drawer(
        child: SafeArea(child: ListView(children: children)),
      );
}
