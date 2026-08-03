import 'package:flutter/material.dart';

import 'vgr_icon.dart';

/// Encapsulates [ListTile] (decision 133).
class VgrListTile extends StatelessWidget {
  const VgrListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.leadingIcon,
    this.trailing,
    this.onTap,
    this.dense = false,
  });

  final String title;
  final String? subtitle;

  /// For rows whose secondary line holds controls rather than text — the
  /// fee-rule row is the case that forced it. Takes precedence over
  /// [subtitle].
  final Widget? subtitleWidget;
  final VgrIconName? leadingIcon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(title),
        subtitle: subtitleWidget ?? (subtitle == null ? null : Text(subtitle!)),
        leading: leadingIcon == null ? null : VgrIcon(leadingIcon!),
        trailing: trailing,
        onTap: onTap,
        dense: dense,
      );
}

/// Encapsulates [CheckboxListTile]. The leading control affinity is fixed
/// here so no screen has to remember it.
class VgrCheckboxTile extends StatelessWidget {
  const VgrCheckboxTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.dense = true,
    this.trailingText,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool dense;

  /// Short text on the opposite side — the menu position of a checked
  /// screen, in the system-modules form.
  final String? trailingText;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
        value: value,
        onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
        title: Text(label),
        secondary: trailingText == null ? null : Text(trailingText!),
        controlAffinity: ListTileControlAffinity.leading,
        dense: dense,
      );
}

/// Encapsulates a bare [Checkbox] — for grids/matrices where a full tile
/// would not fit (the user-privilege matrix is the case that forced it).
class VgrCheckbox extends StatelessWidget {
  const VgrCheckbox({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Checkbox(
        value: value,
        onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
      );
}

/// Encapsulates [SwitchListTile].
class VgrSwitchTile extends StatelessWidget {
  const VgrSwitchTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Text(label),
      );
}

/// Encapsulates [ExpansionTile].
class VgrExpansionTile extends StatelessWidget {
  const VgrExpansionTile({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.initiallyExpanded = false,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  /// Menus open by default; long option lists do not.
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => ExpansionTile(
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        initiallyExpanded: initiallyExpanded,
        children: children,
      );
}

/// Encapsulates [Card] — a visually grouped block.
class VgrCard extends StatelessWidget {
  const VgrCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Card(child: child);
}
