import 'package:flutter/material.dart';

/// The 8-point compass picker for a direction sighting (decision 133; DS2
/// — decisions 200-207). One widget covers both read AND write: a
/// previously-logged/estimated point (`value`) is either read-only
/// (`onChanged` null — the same disabled convention every Vgr* widget
/// follows, e.g. `VgrPrimaryButton(onPressed: null)`) or the point about
/// to be picked. A tap fires [onChanged] with the tapped code
/// IMMEDIATELY — no separate confirm step, mirroring `VgrRating`'s own
/// star tap: a sighting is a low-stakes, append-only contribution, not
/// something needing `showVgrConfirm`.
///
/// Values are the plain 8 wire codes ('N', 'NE', 'E', 'SE', 'S', 'SW',
/// 'W', 'NW'), never a `Direction` enum: this package depends on nothing
/// but `vgr_validators` today (no `packages/core`, no business logic —
/// the Style layer's own rule, `docs/adr/ARCHITECTURE.md`). The caller
/// (`report_detail_page.dart`, which already has both `core`'s
/// `Direction` and `easy_localization` in scope) converts at the
/// boundary.
///
/// Kept deliberately simple — a wrap of 8 labeled chips, not a graphical
/// compass rose: this is a utilitarian design system, not a graphics
/// showcase.
class VgrCompass extends StatelessWidget {
  const VgrCompass({super.key, required this.value, required this.onChanged});

  /// The 8 compass points, in display order.
  static const points = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];

  /// Currently selected/estimated point, or null.
  final String? value;

  /// Fired with the tapped point's code. Null disables every button
  /// (read-only display).
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final point in points)
          _VgrCompassChip(
            point: point,
            selected: value == point,
            color: value == point ? scheme.primary : scheme.outline,
            onTap: onChanged == null ? null : () => onChanged!(point),
          ),
      ],
    );
  }
}

/// One compass point. A generous padded hit area keeps the tap target
/// usable; screen-reader users get a spoken "Direction N" label instead
/// of a bare two-letter code.
class _VgrCompassChip extends StatelessWidget {
  const _VgrCompassChip({
    required this.point,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String point;
  final bool selected;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: onTap != null,
        selected: selected,
        label: 'Direction $point',
        child: GestureDetector(
          key: Key('direction-$point'),
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: color, width: selected ? 2 : 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              point,
              style: TextStyle(
                color: color,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      );
}
