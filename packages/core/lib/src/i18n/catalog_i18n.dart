import 'package:easy_localization/easy_localization.dart';

/// Translates a database-cataloged name: tries `prefix.key` in the JSON
/// catalogs and falls back to the description stored in the database when
/// the key is missing (ported from setes-app's catalog_i18n).
String trCatalog({
  required String prefix,
  required String key,
  required String fallback,
}) {
  final fullKey = '$prefix.$key';
  final translated = fullKey.tr();
  return translated == fullKey ? fallback : translated;
}
