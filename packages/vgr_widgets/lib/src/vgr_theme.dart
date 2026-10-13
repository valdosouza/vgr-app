import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'vgr_colors.dart';

/// The VGR identity as a [ThemeData] (round 24, decisions 255-264).
///
/// Both apps hand [light] and [dark] to `MaterialApp` with
/// `ThemeMode.system`, so the phone's setting decides (decision 256). Every
/// Vgr* widget draws from the theme, which is why one file dresses every
/// screen of both apps (decision 133); the panel gets the same theme and is
/// sober by what it draws, not by a theme of its own (decision 258).
///
/// Color roles:
/// - `primary` is the navy of the mark (selection, links, focus);
/// - the main buttons and the FAB are the teal `action`, the color of
///   acting (report, send);
/// - `error` is the red, kept for panic and errors only (decision 253);
/// - the gold stays out of the scheme's everyday roles: it is the light
///   of the mark and the reward seal (decision 262).
abstract final class VgrTheme {
  /// The bundled family (`packages/vgr_widgets/fonts`), never downloaded
  /// at run time (decision 255).
  static const fontFamily = 'AtkinsonHyperlegibleNext';
  static const fontPackage = 'vgr_widgets';

  /// Fixed-width text (codes, secrets, identifiers), as the full asset
  /// name a [TextStyle] takes: the same family, bundled too.
  static const monoFamily = 'packages/$fontPackage/AtkinsonHyperlegibleMono';

  static ThemeData light() => _build(VgrColors.light, Brightness.light);
  static ThemeData dark() => _build(VgrColors.dark, Brightness.dark);

  /// Adds the fonts' OFL licenses to the app's license page. Call once at
  /// startup; the license asks for it to travel with the font.
  static void registerFontLicense() {
    LicenseRegistry.addLicense(() async* {
      for (final (name, file) in const [
        ('Atkinson Hyperlegible Next', 'OFL.txt'),
        ('Atkinson Hyperlegible Mono', 'OFL-Mono.txt'),
      ]) {
        final text = await rootBundle.loadString('packages/$fontPackage/fonts/$file');
        yield LicenseEntryWithLineBreaks([name], text);
      }
    });
  }

  /// The Material roles, from the identity tokens. The containers stay at
  /// least as light as the page in the light theme, so secondary text keeps
  /// its 4.5:1 on every surface Material puts it on.
  static ColorScheme scheme(VgrColors c, Brightness brightness) {
    final light = brightness == Brightness.light;
    return ColorScheme(
      brightness: brightness,
      primary: c.brand,
      onPrimary: c.onBrand,
      primaryContainer: light ? const Color(0xFFDCE5F5) : const Color(0xFF2A4580),
      onPrimaryContainer: light ? const Color(0xFF0E1F40) : const Color(0xFFDCE5F5),
      secondary: c.action,
      onSecondary: c.onAction,
      secondaryContainer: light ? const Color(0xFFD2EDE8) : const Color(0xFF164A44),
      onSecondaryContainer: light ? const Color(0xFF0B3B36) : const Color(0xFFC9F1EA),
      tertiary: c.accentText,
      onTertiary: light ? const Color(0xFFFFFFFF) : const Color(0xFF0A1120),
      tertiaryContainer: light ? c.accent : const Color(0xFF5A4316),
      onTertiaryContainer: light ? c.onAccent : const Color(0xFFF6E3BF),
      error: c.danger,
      onError: c.onDanger,
      errorContainer: light ? const Color(0xFFFBE4E4) : const Color(0xFF8C1D18),
      onErrorContainer: light ? const Color(0xFF7A1515) : const Color(0xFFFFDAD6),
      surface: c.bg,
      onSurface: c.text,
      onSurfaceVariant: c.muted,
      surfaceContainerLowest: light ? const Color(0xFFFFFFFF) : const Color(0xFF070D19),
      surfaceContainerLow: c.surface,
      surfaceContainer: light ? const Color(0xFFFAFBFC) : c.navSoft,
      surfaceContainerHigh: light ? c.navSoft : c.navStrong,
      surfaceContainerHighest: light ? c.bg : const Color(0xFF1C2842),
      outline: c.control,
      outlineVariant: c.divider,
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
      inverseSurface: light ? c.text : const Color(0xFFE9EDF6),
      onInverseSurface: light ? const Color(0xFFE9EDF6) : const Color(0xFF131D33),
      inversePrimary: light ? VgrColors.dark.brand : VgrColors.light.brand,
      // No tint: elevated surfaces keep the identity's neutrals.
      surfaceTint: const Color(0x00000000),
    );
  }

  static ThemeData _build(VgrColors c, Brightness brightness) {
    final scheme = VgrTheme.scheme(c, brightness);
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      package: fontPackage,
    );
    final text = base.textTheme;
    const radius = BorderRadius.all(Radius.circular(14));
    // Decision 257: 48 dp touch targets.
    const minSize = Size(64, 48);
    final label = text.labelLarge?.copyWith(fontWeight: FontWeight.w700);

    OutlineInputBorder field(Color color, [double width = 1.5]) => OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      extensions: [c],
      scaffoldBackgroundColor: c.bg,
      textTheme: text.copyWith(
        headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.text,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(color: c.text, fontWeight: FontWeight.w700),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.action,
          foregroundColor: c.onAction,
          minimumSize: minSize,
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: radius),
          textStyle: label,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.action,
          foregroundColor: c.onAction,
          minimumSize: minSize,
          shape: const RoundedRectangleBorder(borderRadius: radius),
          textStyle: label,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.brand,
          minimumSize: minSize,
          side: BorderSide(color: c.control, width: 1.5),
          shape: const RoundedRectangleBorder(borderRadius: radius),
          textStyle: label,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.brand,
          minimumSize: minSize,
          textStyle: label,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.action,
        foregroundColor: c.onAction,
        elevation: 2,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.action : null,
        ),
        checkColor: WidgetStatePropertyAll(c.onAction),
        side: BorderSide(color: c.control, width: 2),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(5))),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.action : c.control,
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.action : null,
        ),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.onAction : null,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        border: field(c.control),
        enabledBorder: field(c.control),
        focusedBorder: field(c.brand, 2),
        errorBorder: field(c.danger),
        focusedErrorBorder: field(c.danger, 2),
        disabledBorder: field(c.divider),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: c.divider),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.divider, space: 1, thickness: 1),
      listTileTheme: ListTileThemeData(
        iconColor: c.muted,
        selectedColor: c.brand,
        selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.5),
      ),
      dialogTheme: const DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.brand),
    );
  }
}
