import 'br_tax_id.dart';
import 'contact_filter.dart';
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

  /// Mirrors `z.string().min(n)` on a free-text field — e.g.
  /// `freezeReasonDto` (`api/src/modules/reports/case-freeze.dto.ts`,
  /// decision 141: the reason is mandatory, at least 3 characters). Blank
  /// is `REQUIRED`; shorter than [min] after trimming is `TOO_SHORT {min}`.
  static VgrValidator minLength(int min) => (String value) {
        final v = value.trim();
        if (v.isEmpty) return _required;
        return v.length < min
            ? VgrFieldError(VgrFieldCode.tooShort, {'min': '$min'})
            : null;
      };

  /// Mirrors `z.string().max(n)` on a free-text field — e.g. the `note` of
  /// `moderationReasonDto` (`api/src/shared/moderation/moderation-reason.ts`,
  /// decision 163: at most 500 characters). Blank passes: whether the
  /// field is required is a separate rule the screen lists (or not).
  static VgrValidator maxLength(int max) => (String value) => value.trim().length > max
      ? VgrFieldError(VgrFieldCode.tooLong, {'max': '$max'})
      : null;

  /// Mirrors the `YYYY-MM-DD` form accepted by the panel report search
  /// `from`/`to` query (`api/src/modules/reports/reports-admin.dto.ts`,
  /// phase B1). Shape AND calendar validity: `2026-02-30` is
  /// `INVALID_FORMAT`, the way the API's date parsing rejects it.
  static final _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  static VgrFieldError? isoDate(String value) {
    final v = value.trim();
    if (v.isEmpty) return _required;
    if (!_isoDate.hasMatch(v)) return const VgrFieldError(VgrFieldCode.invalidFormat);
    final parsed = DateTime.tryParse(v);
    // DateTime.parse rolls invalid days over (Feb 30 -> Mar 2); the
    // round-trip catches that.
    if (parsed == null) return const VgrFieldError(VgrFieldCode.invalidFormat);
    final roundTrip = '${parsed.year.toString().padLeft(4, '0')}-'
        '${parsed.month.toString().padLeft(2, '0')}-'
        '${parsed.day.toString().padLeft(2, '0')}';
    return roundTrip == v ? null : const VgrFieldError(VgrFieldCode.invalidFormat);
  }

  /// Mirrors the anti-contact rule of the masked chat — `findContact` in
  /// `api/src/shared/chat/contact-filter.ts`, applied by `chat.service.post`
  /// (decision 171). A hit is `CONTACT_NOT_ALLOWED {kind, match}`, the
  /// API's own field error, so the screen translates local and server
  /// refusals through one key. Blank passes: `required` is a separate rule.
  static VgrFieldError? noDirectContact(String value) {
    final hit = findContact(value);
    if (hit == null) return null;
    return VgrFieldError(
      VgrFieldCode.contactNotAllowed,
      {'kind': hit.kind.name, 'match': hit.match},
    );
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
