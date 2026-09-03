# Shared validators and masks — packages/vgr_validators

Decisions 153–157 in `AI/docs/decisions/VGR-plano.md` (round 10, closed
2026-09-02; plan: `AI/docs/plans/plano-validadores.md`). Until then the
package was the untouched `flutter create` template with zero consumers,
found by the TDD audit of 2026-08-22.

## What it is — and is not

- **Feedback, never security.** The API always revalidates (decisions
  47/110). A rule here exists so a typo is caught before the round-trip —
  which matters most with the offline queue (decision 28), where a server
  422 would arrive hours later.
- **Minimal, on demand (153).** Only rules a real form already needs:
  today that is the helper's payout onboarding (`reward_onboarding`).
  Building a full shared validation module on the API side (option B of
  the round) is deferred until a second form with format fields appears.
- **Mirror, proved by test (154).** Each validator names the Zod rule it
  mirrors in its doc comment (`reward.dto.ts`, `br-tax-id.ts`, zod's own
  email regex) and `test/` reproduces the API's fixtures case by case.
  If either side changes, the other changes in the same commit (invariant
  5: amend before diverging).
- **Codes, not text (157).** A validator returns `VgrFieldError(code,
  params)` where `code` is one of the API's own `FieldErrorCodes`
  (decision 83). The screen translates it through `core.fieldErrors.<code>`
  via `fieldFailureText` — the same path a server field error takes, so
  local and remote errors read identically.

## API surface

| Symbol | Mirrors | Notes |
|---|---|---|
| `VgrValidators.required` | Zod missing field / `min(1)` | blank → `REQUIRED` |
| `VgrValidators.email` | `z.string().email()` | zod 3.25 regex verbatim |
| `VgrValidators.brTaxId` | `brTaxIdSchema` (`api/src/modules/reward/br-tax-id.ts`, decision 155) | strips the mask, 11 = CPF / 14 = CNPJ, check digits → `INVALID_FORMAT` |
| `VgrValidators.brPhone` | `onboardRecipientDto.mobilePhone min(10).max(13)` | on unmasked digits; `TOO_SHORT {min}` / `TOO_LONG {max}` |
| `VgrValidators.cep` | `onboardRecipientDto.address.postalCode min(8).max(9)` | exactly 8 digits (the app always sends the unmasked form) |
| `VgrValidators.positiveNumber` | `z.number().positive()` | `INVALID_VALUE` |
| `VgrValidators.minLength(n)` | `z.string().min(n)` — `freezeReasonDto` (case-freeze, decision 141) | returns a validator; blank → `REQUIRED`, shorter → `TOO_SHORT {min}` |
| `VgrValidators.isoDate` | `from`/`to` of `reports-admin.dto.ts` (B1) | `YYYY-MM-DD` shape AND calendar validity → `INVALID_FORMAT` |
| `VgrValidators.noDirectContact` | `findContact` in `api/src/shared/chat/contact-filter.ts` (masked chat, decision 171) | `CONTACT_NOT_ALLOWED {kind, match}`; `findContact`/`ContactHit`/`ContactKind` exported; `test/contact_filter_test.dart` carries the API spec fixtures one by one; accents stripped by a Latin table (no NFD in Dart) |
| `VgrValidators.validate({field: (value, [rules])})` | — | first error per field, straight into a screen's `errorText` map |
| `isValidCpf` / `isValidCnpj` / `isValidBrTaxId` | same functions in `br-tax-id.ts` | digits only |
| `unmask(text)` | — | digits only — what goes on the wire (155) |
| `VgrMask.{cpfCnpj, phoneBr, cep}` + `VgrMaskFormatter` | — | UX only; caps at the longest domestic form even where the API rule is looser |

## Where the mask goes (157 + 133)

`VgrTextField(mask: VgrMask.cpfCnpj)` — the screen names the mask, the
design system builds the `inputFormatters`, the formatter lives in this
package. No screen imports `flutter/services` or touches a
`TextInputFormatter`; no widget carries a format rule.

## Screen pattern (see `reward_onboarding_page.dart`)

```dart
final errors = VgrValidators.validate({
  'taxId': (_taxId.text, [VgrValidators.brTaxId]),
  'postalCode': (_postalCode.text, [VgrValidators.cep]),
});
// translate each code exactly like a server field error (decision 83)
_fieldErrors = { for (final e in errors.entries) e.key: fieldFailureText(FieldFailure(...)) };
// send digits only (decision 155)
taxId: unmask(_taxId.text)
```

## Deliberately not done (decision 156)

No guard test forbids inline `RegExp(` / `length <` checks in
`presentation/` yet; the three admin screens that do it (`case_freeze`,
`legal_rules`, `legal_capabilities`) stay as they are. The rule is review
discipline until option B of the round is reopened: a new screen with a
format field uses this package, never an inline regex.
