import 'package:flutter/material.dart';

/// The VGR identity colors, by role (decisions 261-264, round 24).
///
/// Mirrors `vgr-ai/docs/identidade-visual/v1b/gerador/tokens.py`, where each
/// pair was checked against the WCAG AA floor of decision 257; the same
/// pairs are checked again here by `test/vgr_colors_test.dart`, so a color
/// changed in one place and not the other fails the build.
///
/// Screens never read these directly: the Vgr* widgets do, through
/// [VgrColors.of], or the [ThemeData] built by `VgrTheme` does.
@immutable
class VgrColors extends ThemeExtension<VgrColors> {
  const VgrColors({
    required this.bg,
    required this.surface,
    required this.text,
    required this.muted,
    required this.brand,
    required this.onBrand,
    required this.action,
    required this.onAction,
    required this.accent,
    required this.onAccent,
    required this.accentGraphic,
    required this.accentText,
    required this.control,
    required this.divider,
    required this.danger,
    required this.onDanger,
    required this.navStrong,
    required this.navSoft,
    required this.splash,
  });

  /// Page background.
  final Color bg;

  /// Cards, fields, sheets.
  final Color surface;

  /// Main text.
  final Color text;

  /// Secondary text: captions, hints, distances.
  final Color muted;

  /// The navy of the mark: selection, links, identity.
  final Color brand;
  final Color onBrand;

  /// The teal of Valdo's board: the color of acting (report, send).
  final Color action;
  final Color onAction;

  /// The gold as a fill — the reward seal of decision 101 (262).
  final Color accent;
  final Color onAccent;

  /// The gold drawn on this theme's surfaces (>= 3:1).
  final Color accentGraphic;

  /// The gold as text (>= 4.5:1).
  final Color accentText;

  /// Checkbox and field borders (>= 3:1).
  final Color control;

  /// Decorative lines; no contrast floor.
  final Color divider;

  /// Panic and errors only (decision 253).
  final Color danger;
  final Color onDanger;

  /// The panel's two navigation columns (decision 215).
  final Color navStrong;
  final Color navSoft;

  /// The opening screen.
  final Color splash;

  static const light = VgrColors(
    bg: Color(0xFFF4F6F8),
    surface: Color(0xFFFFFFFF),
    text: Color(0xFF131D33),
    muted: Color(0xFF627289),
    brand: Color(0xFF203B70),
    onBrand: Color(0xFFFFFFFF),
    action: Color(0xFF1B7168),
    onAction: Color(0xFFFFFFFF),
    accent: Color(0xFFD8A34D),
    onAccent: Color(0xFF131D33),
    accentGraphic: Color(0xFFBB8329),
    accentText: Color(0xFF946820),
    control: Color(0xFF788499),
    divider: Color(0xFFDDE2EA),
    danger: Color(0xFFD23535),
    onDanger: Color(0xFFFFFFFF),
    navStrong: Color(0xFFE6EAF1),
    navSoft: Color(0xFFF7F8FB),
    splash: Color(0xFF203B70),
  );

  /// Designed with the light one, never inverted from it (decision 256).
  static const dark = VgrColors(
    bg: Color(0xFF0A1120),
    surface: Color(0xFF111A2D),
    text: Color(0xFFE9EDF6),
    muted: Color(0xFFA9B3C9),
    brand: Color(0xFF93B6FF),
    onBrand: Color(0xFF0A1120),
    action: Color(0xFF5CCDBB),
    onAction: Color(0xFF05201C),
    accent: Color(0xFFD8A34D),
    onAccent: Color(0xFF0A1120),
    accentGraphic: Color(0xFFD8A34D),
    accentText: Color(0xFFD8A34D),
    control: Color(0xFF7D88A3),
    divider: Color(0xFF243049),
    danger: Color(0xFFFFB4AB),
    onDanger: Color(0xFF4A0B07),
    navStrong: Color(0xFF18233A),
    navSoft: Color(0xFF141E33),
    splash: Color(0xFF0A1120),
  );

  /// The colors of the current theme; falls back to the brightness default
  /// when a test pumps a bare MaterialApp.
  static VgrColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<VgrColors>() ?? (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  VgrColors copyWith({
    Color? bg,
    Color? surface,
    Color? text,
    Color? muted,
    Color? brand,
    Color? onBrand,
    Color? action,
    Color? onAction,
    Color? accent,
    Color? onAccent,
    Color? accentGraphic,
    Color? accentText,
    Color? control,
    Color? divider,
    Color? danger,
    Color? onDanger,
    Color? navStrong,
    Color? navSoft,
    Color? splash,
  }) =>
      VgrColors(
        bg: bg ?? this.bg,
        surface: surface ?? this.surface,
        text: text ?? this.text,
        muted: muted ?? this.muted,
        brand: brand ?? this.brand,
        onBrand: onBrand ?? this.onBrand,
        action: action ?? this.action,
        onAction: onAction ?? this.onAction,
        accent: accent ?? this.accent,
        onAccent: onAccent ?? this.onAccent,
        accentGraphic: accentGraphic ?? this.accentGraphic,
        accentText: accentText ?? this.accentText,
        control: control ?? this.control,
        divider: divider ?? this.divider,
        danger: danger ?? this.danger,
        onDanger: onDanger ?? this.onDanger,
        navStrong: navStrong ?? this.navStrong,
        navSoft: navSoft ?? this.navSoft,
        splash: splash ?? this.splash,
      );

  @override
  VgrColors lerp(VgrColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return VgrColors(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      text: l(text, other.text),
      muted: l(muted, other.muted),
      brand: l(brand, other.brand),
      onBrand: l(onBrand, other.onBrand),
      action: l(action, other.action),
      onAction: l(onAction, other.onAction),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      accentGraphic: l(accentGraphic, other.accentGraphic),
      accentText: l(accentText, other.accentText),
      control: l(control, other.control),
      divider: l(divider, other.divider),
      danger: l(danger, other.danger),
      onDanger: l(onDanger, other.onDanger),
      navStrong: l(navStrong, other.navStrong),
      navSoft: l(navSoft, other.navSoft),
      splash: l(splash, other.splash),
    );
  }
}

/// The mark's own colors, the same in both themes: the app icon and the
/// negative logo always sit on the navy.
abstract final class VgrMarkColors {
  static const navy = Color(0xFF203B70);
  static const white = Color(0xFFFFFFFF);
  static const gold = Color(0xFFD8A34D);
}
