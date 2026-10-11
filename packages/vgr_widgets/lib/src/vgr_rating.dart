import 'package:flutter/material.dart';

import 'vgr_icon.dart';

/// Helper rating control (decision 133; RT2 — the helper-rating front,
/// decisions 48/178-189). One widget covers both read AND write: a score
/// (`value`, 1..[starCount]) is either what the offer already carries
/// (183 — immutable once given, rendered read-only) or what the owner is
/// about to give. [onChanged] null means read-only/disabled — the same
/// convention every Vgr* widget follows (`VgrPrimaryButton(onPressed:
/// null)`); the caller (the screen) decides read-only-ness from the
/// server's `ratable` flag, this widget never invents that rule.
class VgrRating extends StatelessWidget {
  const VgrRating({
    super.key,
    required this.value,
    required this.onChanged,
    required this.starLabel,
    this.starCount = 5,
    this.size = 28,
  });

  /// Current score, or null when this offer has none yet.
  final int? value;

  /// Fired with the tapped star's 1-based index. Null disables every star.
  final ValueChanged<int>? onChanged;

  /// What a screen reader says for star N ("3 estrelas") — supplied by the
  /// app, which owns the translation catalogs; the design system has none.
  /// It was a hard-coded English "Rate N stars" until the mobile browser
  /// test of 2026-10-04 heard it inside the Portuguese UI.
  final String Function(int stars) starLabel;

  final int starCount;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= starCount; i++)
          _VgrRatingStar(
            index: i,
            filled: value != null && i <= value!,
            size: size,
            color: value != null && i <= value! ? scheme.primary : scheme.outline,
            label: starLabel(i),
            onTap: onChanged == null ? null : () => onChanged!(i),
          ),
      ],
    );
  }
}

/// One star. A 40x40 opaque hit area keeps the tap target usable even at
/// a small icon [size] — screen-reader users get the spoken [label]
/// instead of a bare icon.
class _VgrRatingStar extends StatelessWidget {
  const _VgrRatingStar({
    required this.index,
    required this.filled,
    required this.size,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final int index;
  final bool filled;
  final double size;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: onTap != null,
        label: label,
        child: GestureDetector(
          key: Key('rating-star-$index'),
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: VgrIcon(
                filled ? VgrIconName.starFilled : VgrIconName.starOutline,
                size: size,
                color: color,
              ),
            ),
          ),
        ),
      );
}
