import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;

import '../../network/api_client.dart';
import '../data/preference_repository_impl.dart';
import '../domain/preference_repository.dart';

/// Applies the user's server-saved locale after login/session restore
/// (called from the Home — ported from setes-app's locale_sync). Best
/// effort: any failure keeps the current locale silently.
Future<void> applyUserLocale(BuildContext context, {PreferenceRepository? repository}) async {
  try {
    final repo = repository ?? PreferenceRepositoryImpl(Modular.get<ApiClient>());
    final result = await repo.getMyLocale();
    await result.fold((_) async {}, (tag) async {
      if (tag == null || !context.mounted) return;
      final parts = tag.split('-');
      final locale = parts.length == 2 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
      if (context.supportedLocales.contains(locale) && context.locale != locale) {
        await context.setLocale(locale);
      }
    });
  } catch (_) {}
}
