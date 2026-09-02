/// Per-field codes — the SAME strings the API emits in `fields[].code`
/// (`api/src/shared/errors/error-codes.ts`, `FieldErrorCodes`, decision 83),
/// so a screen translates a local and a server error through the one key
/// `core.fieldErrors.<code>`.
abstract final class VgrFieldCode {
  static const required = 'REQUIRED';
  static const tooShort = 'TOO_SHORT';
  static const tooLong = 'TOO_LONG';
  static const invalidEmail = 'INVALID_EMAIL';
  static const invalidFormat = 'INVALID_FORMAT';
  static const invalidOption = 'INVALID_OPTION';
  static const invalidValue = 'INVALID_VALUE';
}

/// A validator's verdict: a code and its interpolation params (decision
/// 157 — never a message). `null` from a validator means "valid".
class VgrFieldError {
  const VgrFieldError(this.code, [this.params = const {}]);

  final String code;
  final Map<String, String> params;

  @override
  bool operator ==(Object other) =>
      other is VgrFieldError &&
      other.code == code &&
      other.params.length == params.length &&
      other.params.entries.every((e) => params[e.key] == e.value);

  @override
  int get hashCode => Object.hash(code, params.length);

  @override
  String toString() => 'VgrFieldError($code, $params)';
}
