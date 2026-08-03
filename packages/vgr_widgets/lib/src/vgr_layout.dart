import 'package:flutter/material.dart';

/// Layout primitives (decision 133).
///
/// These wrappers are intentionally thin. They exist so the rule has no
/// exceptions to argue about at review time — "is Column allowed?" is a
/// question nobody should have to ask twice — and so spacing becomes a
/// scale instead of scattered magic numbers.

/// The spacing scale. Screens say `VgrGap.md`, never `SizedBox(height: 16)`.
class VgrGap extends StatelessWidget {
  const VgrGap._(this._size, this._horizontal);

  const VgrGap.xs() : this._(4, false);
  const VgrGap.sm() : this._(8, false);
  const VgrGap.md() : this._(16, false);
  const VgrGap.lg() : this._(24, false);
  const VgrGap.xl() : this._(40, false);

  /// Horizontal spacing of the same scale.
  const VgrGap.hSm() : this._(8, true);
  const VgrGap.hMd() : this._(16, true);

  final double _size;
  final bool _horizontal;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: _horizontal ? _size : null, height: _horizontal ? null : _size);
}

/// Encapsulates [Column].
class VgrColumn extends StatelessWidget {
  const VgrColumn({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.shrink = true,
  });

  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;

  /// True keeps the column as small as its content — the common case in
  /// forms, and the one people forget, producing stretched layouts.
  final bool shrink;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: shrink ? MainAxisSize.min : MainAxisSize.max,
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: children,
      );
}

/// Encapsulates [Row].
class VgrRow extends StatelessWidget {
  const VgrRow({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.shrink = true,
  });

  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;

  /// Defaults to true, unlike Flutter's Row: a row that takes all the
  /// width it can is exactly what breaks a ListTile trailing slot, and
  /// that mistake is easier to prevent here than to diagnose per screen.
  final bool shrink;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: shrink ? MainAxisSize.min : MainAxisSize.max,
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: children,
      );
}

/// Encapsulates [Padding] with the same scale as [VgrGap].
class VgrPadding extends StatelessWidget {
  const VgrPadding({super.key, required this.child, this.all = 16});

  const VgrPadding.screen({super.key, required this.child}) : all = 16;

  final Widget child;
  final double all;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: EdgeInsets.all(all), child: child);
}

/// Encapsulates [SingleChildScrollView] — content that can overflow on a
/// short window, which on the web panel is most forms.
class VgrScrollView extends StatelessWidget {
  const VgrScrollView({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(child: child);
}

/// Encapsulates [Expanded] for children that must fill the remaining space.
class VgrExpanded extends StatelessWidget {
  const VgrExpanded({super.key, required this.child, this.flex = 1});

  final Widget child;
  final int flex;

  @override
  Widget build(BuildContext context) => Expanded(flex: flex, child: child);
}

/// Encapsulates [Divider].
class VgrDivider extends StatelessWidget {
  const VgrDivider({super.key});

  @override
  Widget build(BuildContext context) => const Divider();
}

/// Encapsulates [ListView] for an already-built list of children.
class VgrListView extends StatelessWidget {
  const VgrListView({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(children: children);
}

/// Encapsulates [Center].
class VgrCenter extends StatelessWidget {
  const VgrCenter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(child: child);
}

/// Encapsulates [StatefulBuilder] — local state inside a dialog, whose
/// content is built outside the parent's element tree and therefore cannot
/// use the parent's setState.
class VgrStatefulContent extends StatelessWidget {
  const VgrStatefulContent({super.key, required this.builder});

  /// `refresh` is the local setState: call it with the mutation.
  final Widget Function(BuildContext context, void Function(VoidCallback) refresh) builder;

  @override
  Widget build(BuildContext context) =>
      StatefulBuilder(builder: (innerContext, setState) => builder(innerContext, setState));
}

/// Encapsulates a fixed-width [SizedBox] — narrow inputs inside a row,
/// where letting the field take the whole width would be wrong.
class VgrFixedWidth extends StatelessWidget {
  const VgrFixedWidth({super.key, required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(width: width, child: child);
}
