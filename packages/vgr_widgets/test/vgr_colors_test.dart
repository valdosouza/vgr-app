import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

/// Decision 257: WCAG AA is the floor — 4.5:1 for text, 3:1 for graphics
/// and control borders. The pairs are the ones `tokens.py` checks in
/// vgr-ai (v1b/gerador), plus the Material roles VgrTheme derives, so a
/// color changed here and not there, or one that breaks the floor, fails.
double _lin(double c) => c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) => 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);

double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

typedef _Pair = (String, Color Function(VgrColors), Color Function(VgrColors), double);

final _tokenPairs = <_Pair>[
  ('text on bg', (c) => c.text, (c) => c.bg, 4.5),
  ('text on surface', (c) => c.text, (c) => c.surface, 4.5),
  ('muted on bg', (c) => c.muted, (c) => c.bg, 4.5),
  ('muted on surface', (c) => c.muted, (c) => c.surface, 4.5),
  ('brand on surface', (c) => c.brand, (c) => c.surface, 4.5),
  ('onBrand on brand', (c) => c.onBrand, (c) => c.brand, 4.5),
  ('onAction on action', (c) => c.onAction, (c) => c.action, 4.5),
  ('action on bg', (c) => c.action, (c) => c.bg, 3),
  ('onAccent on accent', (c) => c.onAccent, (c) => c.accent, 4.5),
  ('accentText on surface', (c) => c.accentText, (c) => c.surface, 4.5),
  ('accentGraphic on surface', (c) => c.accentGraphic, (c) => c.surface, 3),
  ('accentGraphic on bg', (c) => c.accentGraphic, (c) => c.bg, 3),
  ('danger on surface', (c) => c.danger, (c) => c.surface, 4.5),
  ('onDanger on danger', (c) => c.onDanger, (c) => c.danger, 4.5),
  ('control on surface', (c) => c.control, (c) => c.surface, 3),
  ('text on navStrong', (c) => c.text, (c) => c.navStrong, 4.5),
  ('muted on navSoft', (c) => c.muted, (c) => c.navSoft, 4.5),
];

typedef _SchemePair = (String, Color Function(ColorScheme), Color Function(ColorScheme), double);

final _schemePairs = <_SchemePair>[
  ('onPrimaryContainer', (s) => s.onPrimaryContainer, (s) => s.primaryContainer, 4.5),
  ('onSecondaryContainer', (s) => s.onSecondaryContainer, (s) => s.secondaryContainer, 4.5),
  ('onTertiary', (s) => s.onTertiary, (s) => s.tertiary, 4.5),
  ('onTertiaryContainer', (s) => s.onTertiaryContainer, (s) => s.tertiaryContainer, 4.5),
  ('onErrorContainer', (s) => s.onErrorContainer, (s) => s.errorContainer, 4.5),
  ('onInverseSurface', (s) => s.onInverseSurface, (s) => s.inverseSurface, 4.5),
  ('inversePrimary on inverseSurface', (s) => s.inversePrimary, (s) => s.inverseSurface, 3),
  // Material puts secondary text on every container.
  for (final (name, of) in <(String, Color Function(ColorScheme))>[
    ('surface', (s) => s.surface),
    ('surfaceContainerLowest', (s) => s.surfaceContainerLowest),
    ('surfaceContainerLow', (s) => s.surfaceContainerLow),
    ('surfaceContainer', (s) => s.surfaceContainer),
    ('surfaceContainerHigh', (s) => s.surfaceContainerHigh),
    ('surfaceContainerHighest', (s) => s.surfaceContainerHighest),
  ])
    ('onSurfaceVariant on $name', (s) => s.onSurfaceVariant, of, 4.5),
  ('outline on surface', (s) => s.outline, (s) => s.surface, 3),
];

void main() {
  for (final (mode, colors, theme) in [
    ('light', VgrColors.light, VgrTheme.light()),
    ('dark', VgrColors.dark, VgrTheme.dark()),
  ]) {
    group('$mode theme meets WCAG AA (decision 257)', () {
      for (final (name, fg, bg, min) in _tokenPairs) {
        test(name, () {
          final ratio = contrast(fg(colors), bg(colors));
          expect(ratio, greaterThanOrEqualTo(min), reason: '$name is ${ratio.toStringAsFixed(2)}:1');
        });
      }
      for (final (name, fg, bg, min) in _schemePairs) {
        test(name, () {
          final ratio = contrast(fg(theme.colorScheme), bg(theme.colorScheme));
          expect(ratio, greaterThanOrEqualTo(min), reason: '$name is ${ratio.toStringAsFixed(2)}:1');
        });
      }
    });
  }

  test('the mark on its navy: white arc and gold dot', () {
    expect(contrast(VgrMarkColors.white, VgrMarkColors.navy), greaterThanOrEqualTo(3));
    expect(contrast(VgrMarkColors.gold, VgrMarkColors.navy), greaterThanOrEqualTo(3));
  });

  test('the themes carry the tokens, the bundled font and the action teal', () {
    final light = VgrTheme.light();
    final dark = VgrTheme.dark();
    expect(light.extension<VgrColors>(), VgrColors.light);
    expect(dark.extension<VgrColors>(), VgrColors.dark);
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.textTheme.bodyMedium?.fontFamily, 'packages/vgr_widgets/${VgrTheme.fontFamily}');
    expect(light.colorScheme.primary, VgrColors.light.brand);
    expect(light.colorScheme.error, VgrColors.light.danger);
    expect(light.floatingActionButtonTheme.backgroundColor, VgrColors.light.action);
    expect(dark.scaffoldBackgroundColor, VgrColors.dark.bg);
  });

  test('the hex values match the V1b tokens of vgr-ai (tokens.py)', () {
    String hex(Color c) => '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    expect(hex(VgrColors.light.brand), '#203B70');
    expect(hex(VgrColors.light.action), '#1B7168');
    expect(hex(VgrColors.light.accent), '#D8A34D');
    expect(hex(VgrColors.light.accentGraphic), '#BB8329');
    expect(hex(VgrColors.light.muted), '#627289');
    expect(hex(VgrColors.light.danger), '#D23535');
    expect(hex(VgrColors.dark.bg), '#0A1120');
    expect(hex(VgrColors.dark.brand), '#93B6FF');
    expect(hex(VgrColors.dark.action), '#5CCDBB');
  });
}
