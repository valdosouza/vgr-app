import 'package:flutter/widgets.dart';

/// Breakpoint helper ported from setes-app's `Responsive` (decision 218 —
/// a structural piece, exempt from the "no raw widget in screens" rule
/// like `MediaQuery` itself). Mobile below 850, tablet 850–1099, desktop
/// from 1100 — the same thresholds, so the two panels behave alike.
///
/// A screen that differs by breakpoint keeps one widget per breakpoint
/// and lets this one pick; it never reads `MediaQuery` on its own.
class VgrResponsive extends StatelessWidget {
  const VgrResponsive({
    super.key,
    required this.mobile,
    required this.desktop,
    this.tablet,
  });

  final Widget mobile;
  final Widget desktop;

  /// Falls back to [mobile] when absent.
  final Widget? tablet;

  static const double mobileMaxWidth = 850;
  static const double desktopMinWidth = 1100;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileMaxWidth;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobileMaxWidth && width < desktopMinWidth;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktopMinWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= desktopMinWidth) return desktop;
    if (width >= mobileMaxWidth && tablet != null) return tablet!;
    return mobile;
  }
}
