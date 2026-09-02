import 'br_tax_id.dart';
import 'field_error.dart';
import 'mask.dart';

/// One validator = one field rule. Returns `null` when valid.
typedef VgrValidator = VgrFieldError? Function(String value);

/// Format validators of the app, each mirroring one Zod rule in the API
/// (decision 154 — the mirrored rule is named on every method). Blank
/// input is always `REQUIRED`, the way Zod reports a missing field, so a
/// screen lists only the validators it needs and never `required` twice.
abstract final class VgrValidators {
  static const _required = VgrFieldError(VgrFieldCode.required);

  /// Mirrors a Zod `z.string().min(1)` / a missing field.
  static VgrFieldError? required(String value) => value.trim().isEmpty ? _required : null;

  /// Mirrors `z.string().email()` — the exact regex of zod 3.25
  /// (`api/node_modules/zod/v3/types.js`, `emailRegex`).
  static final _email = RegExp(
    r"^(?!\.)(?!.*\.\.)([A-Z0-9_'+\-\.]*)[A-Z0-9_+-]@([A-Z0-9][A-Z0-9\-]*\.)+[A-Z]{2,}$",
    caseSensitive: false,
  );

  static VgrFieldError? email(String value) {
    final v = value.trim();
    if (v.isEmpty) return _required;
    return _email.hasMatch(v) ? null : const VgrFieldError(VgrFieldCode.invalidEmail);
  }

  /// Mirrors `brTaxIdSchema` (`api/src/modules/reward/br-tax-id.ts`,
  /// decision 155): digits only, 11 = CPF / 14 = CNPJ, check digits
  /// verified. The mask is stripped here; the screen sends `unmask(text)`.
  static VgrFieldError? brTaxId(String value) {
    final digits = unmask(value);
    if (digits.isEmpty) return _required;
    return isValidBrTaxId(digits) ? null : const VgrFieldError(VgrFieldCode.invalidFormat);
  }

  /// Mirrors `onboardRecipientDto.mobilePhone: z.string().min(10).max(13)`
  /// (`reward.dto.ts`) on the unmasked digits.
  static VgrFieldError? brPhone(String value) {
    final digits = unmask(value);
    if (digits.isEmpty) return _required;
    if (digits.length < 10) return const VgrFieldError(VgrFieldCode.tooShort, {'min': '10'});
    if (digits.length > 13) return const VgrFieldError(VgrFieldCode.tooLong, {'max': '13'});
    return null;
  }

  /// Mirrors `onboardRecipientDto.address.postalCode: z.string().min(8).max(9)`
  /// (`reward.dto.ts`). The API tolerates the 9-char masked form; the app
  /// always sends the 8-digit unmasked one, so exactly 8 digits here.
  static VgrFieldError? cep(String value) {
    final digits = unmask(value);
    if (digits.isEmpty) return _required;
    return digits.length == 8 ? null : const VgrFieldError(VgrFieldCode.invalidFormat);
  }

  /// Mirrors `z.number().positive()` (e.g. `onboardRecipientDto.monthlyIncome`).
  static VgrFieldError? positiveNumber(String value) {
    final v = value.trim();
    if (v.isEmpty) return _required;
    final n = num.tryParse(v);
    return n != null && n > 0 ? null : const VgrFieldError(VgrFieldCode.invalidValue);
  }

  /// Runs each field's validators in order and keeps the first error per
  /// field — the shape a screen puts straight into its `errorText` map.
  static Map<String, VgrFieldError> validate(
    Map<String, (String value, List<VgrValidator> rules)> fields,
  ) {
    final errors = <String, VgrFieldError>{};
    for (final entry in fields.entries) {
      final (value, rules) = entry.value;
      for (final rule in rules) {
        final error = rule(value);
        if (error != null) {
          errors[entry.key] = error;
          break;
        }
      }
    }
    return errors;
  }
}
