import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;

import '../../network/api_client.dart';
import '../data/preference_repository_impl.dart';
import '../domain/preference_repository.dart';

/// AppBar language switcher (ported from setes-app). On the login page use
/// `persist: false` (no session yet — local switch only); post-login use
/// `persist: true` so the choice is saved via PUT /api/core/preferences and
/// follows the user to any browser.
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key, required this.persist, this.repository});

  final bool persist;

  /// Injectable for tests; defaults to the ApiClient-backed implementation.
  final PreferenceRepository? repository;

  // Endonyms on purpose — a language's own name needs no translation.
  static const _options = [
    (Locale('en', 'US'), 'English (US)'),
    (Locale('pt', 'BR'), 'Português (BR)'),
  ];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Locale>(
      key: const Key('language-selector'),
      icon: const Icon(Icons.language),
      tooltip: 'app.language'.tr(),
      onSelected: (locale) async {
        await context.setLocale(locale);
        if (!persist) return;
        // Best-effort: a failed save never blocks the local switch.
        try {
          final repo = repository ?? PreferenceRepositoryImpl(Modular.get<ApiClient>());
          await repo.saveLocale(locale.toStringWithSeparator(separator: '-'));
        } catch (_) {}
      },
      itemBuilder: (context) => [
        for (final (locale, label) in _options)
          PopupMenuItem(
            key: Key('language-option-${locale.toStringWithSeparator(separator: '-')}'),
            value: locale,
            child: Row(
              children: [
                if (context.locale == locale)
                  const Icon(Icons.check, size: 16)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(label),
              ],
            ),
          ),
      ],
    );
  }
}
