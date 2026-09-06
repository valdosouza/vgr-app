import 'package:easy_localization/easy_localization.dart';

import 'failure.dart';

/// Translates a [Failure] by its catalog code (decisions 80/83): tries
/// `core.errors.<code>` with the failure's params as named args; falls back
/// to the API's English message when the key (or code) is missing.
///
/// A code whose WORDING depends on a param value — not one that merely
/// interpolates it — holds a map instead of a string, keyed by the param
/// name and then its value, with an `other` leaf as the generic sentence
/// (the shape easy_localization gives gender/plural forms):
///
///     "RATING_CLOSED": {
///       "reason": { "open": "…still open.", "hidden": "…was hidden." },
///       "other": "…after the case is closed."
///     }
///
/// Lookup order: `<code>.<param>.<value>` for each param, then
/// `<code>.other`, then the plain `<code>` — always leaf-first, because
/// easy_localization throws when a key resolves to a map node rather than
/// a string. A variant map therefore MUST carry `other`; the plain key is
/// only reached when nothing above it resolved. Plain string codes keep
/// resolving exactly as before: easy_localization 3.x answers a deeper key
/// on a string leaf with that string, and the plain key is the last resort
/// anyway.
String failureText(Failure failure) {
  final code = failure.code;
  if (code == null) return failure.message;

  final key = 'core.errors.$code';
  final params = failure.params ?? const <String, String>{};
  final candidates = [
    for (final param in params.entries) '$key.${param.key}.${param.value}',
    '$key.other',
    key,
  ];
  for (final candidate in candidates) {
    final translated = candidate.tr(namedArgs: params);
    if (translated != candidate) return translated;
  }
  return failure.message;
}

/// Same contract for a single field error (`core.fieldErrors.<code>`).
/// No variant lookup here on purpose: field params carry user-typed text
/// (`CONTACT_NOT_ALLOWED`'s `match`), which must never become a lookup key.
String fieldFailureText(FieldFailure field) {
  final code = field.code;
  if (code == null) return field.message;

  final key = 'core.fieldErrors.$code';
  final translated = key.tr(namedArgs: field.params ?? const {});
  return translated == key ? field.message : translated;
}
