import 'package:easy_localization/easy_localization.dart';

import 'failure.dart';

/// Translates a [Failure] by its catalog code (decisions 80/83): tries
/// `core.errors.<code>` with the failure's params as named args; falls back
/// to the API's English message when the key (or code) is missing.
String failureText(Failure failure) {
  final code = failure.code;
  if (code == null) return failure.message;

  final key = 'core.errors.$code';
  final translated = key.tr(namedArgs: failure.params ?? const {});
  return translated == key ? failure.message : translated;
}

/// Same contract for a single field error (`core.fieldErrors.<code>`).
String fieldFailureText(FieldFailure field) {
  final code = field.code;
  if (code == null) return field.message;

  final key = 'core.fieldErrors.$code';
  final translated = key.tr(namedArgs: field.params ?? const {});
  return translated == key ? field.message : translated;
}
