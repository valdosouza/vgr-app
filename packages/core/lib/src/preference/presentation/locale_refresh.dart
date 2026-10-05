import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

/// Rebuilds the whole subtree when the app's language changes.
///
/// Screens translate with `'key'.tr()` — the form WITHOUT a context, which
/// does not subscribe the widget to the locale. A switch (the selector, or
/// `LocaleSync` applying the user's saved language after login) therefore
/// repainted only the widgets that happen to read the locale: the open
/// screen kept its old language until the user navigated away (found in the
/// panel's browser test of 2026-10-04). Wrapping the app in this widget marks
/// every element below dirty once per change, so each `.tr()` re-reads the
/// new catalog; State objects (blocs, typed text) are kept — nothing is
/// recreated.
class LocaleRefresh extends StatefulWidget {
  const LocaleRefresh({super.key, required this.child});

  final Widget child;

  @override
  State<LocaleRefresh> createState() => _LocaleRefreshState();
}

class _LocaleRefreshState extends State<LocaleRefresh> {
  Locale? _shown;

  @override
  Widget build(BuildContext context) {
    final locale = context.locale;
    if (_shown != null && _shown != locale) {
      // After this frame: the new catalog is loaded and the subtree exists.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) (context as Element).visitChildren(_markDirty);
      });
    }
    _shown = locale;
    return widget.child;
  }

  static void _markDirty(Element element) {
    element.markNeedsBuild();
    element.visitChildren(_markDirty);
  }
}
