import 'package:flutter_test/flutter_test.dart';
import 'package:vgr_validators/vgr_validators.dart';

/// Each validator mirrors ONE Zod rule in the API (decision 154) — the
/// mirrored DTO is named in the group. A validator returns a field code,
/// never text (decision 157): the screen translates it through
/// `core.fieldErrors.<code>`, the same key a server field error uses.
void main() {
  group('VgrValidators.required', () {
    test('blank (including whitespace) → REQUIRED', () {
      expect(VgrValidators.required(''), const VgrFieldError(VgrFieldCode.required));
      expect(VgrValidators.required('   '), const VgrFieldError(VgrFieldCode.required));
    });

    test('anything non-blank passes', () {
      expect(VgrValidators.required('x'), isNull);
    });
  });

  group('VgrValidators.email — mirrors z.string().email() (zod 3.25)', () {
    test('accepts ordinary addresses', () {
      expect(VgrValidators.email('helper@example.com'), isNull);
      expect(VgrValidators.email('first.last+tag@sub.example.co'), isNull);
    });

    test('rejects what Zod rejects', () {
      const bad = ['helper', 'helper@', '@example.com', 'helper@example', 'a..b@example.com', '.a@example.com', 'a@-example.com', 'a b@example.com'];
      for (final value in bad) {
        expect(VgrValidators.email(value), const VgrFieldError(VgrFieldCode.invalidEmail), reason: value);
      }
    });

    test('blank is REQUIRED, not INVALID_EMAIL', () {
      expect(VgrValidators.email(''), const VgrFieldError(VgrFieldCode.required));
    });
  });

  group('VgrValidators.brTaxId — mirrors reward.dto.ts brTaxIdSchema (decision 155)', () {
    test('accepts a valid CPF or CNPJ, masked or not (the mask is stripped)', () {
      expect(VgrValidators.brTaxId('52998224725'), isNull);
      expect(VgrValidators.brTaxId('529.982.247-25'), isNull);
      expect(VgrValidators.brTaxId('11.222.333/0001-81'), isNull);
    });

    test('wrong check digit → INVALID_FORMAT', () {
      expect(VgrValidators.brTaxId('529.982.247-26'), const VgrFieldError(VgrFieldCode.invalidFormat));
    });

    test('12/13 digits → INVALID_FORMAT', () {
      expect(VgrValidators.brTaxId('529982247251'), const VgrFieldError(VgrFieldCode.invalidFormat));
    });

    test('blank is REQUIRED', () {
      expect(VgrValidators.brTaxId(''), const VgrFieldError(VgrFieldCode.required));
    });
  });

  group('VgrValidators.brPhone — mirrors onboardRecipientDto.mobilePhone min(10).max(13)', () {
    test('accepts 10 to 13 digits after unmasking', () {
      expect(VgrValidators.brPhone('(11) 99999-8888'), isNull);
      expect(VgrValidators.brPhone('1133334444'), isNull);
      expect(VgrValidators.brPhone('5511999998888'), isNull);
    });

    test('9 digits → TOO_SHORT with min=10; 14 → TOO_LONG with max=13', () {
      expect(
        VgrValidators.brPhone('119999888'),
        const VgrFieldError(VgrFieldCode.tooShort, {'min': '10'}),
      );
      expect(
        VgrValidators.brPhone('55119999988881'),
        const VgrFieldError(VgrFieldCode.tooLong, {'max': '13'}),
      );
    });
  });

  group('VgrValidators.cep — mirrors onboardRecipientDto.address.postalCode min(8).max(9)', () {
    test('accepts 8 digits, masked or not (the app always sends the 8-digit form)', () {
      expect(VgrValidators.cep('01001-000'), isNull);
      expect(VgrValidators.cep('01001000'), isNull);
    });

    test('anything but 8 digits → INVALID_FORMAT', () {
      expect(VgrValidators.cep('0100100'), const VgrFieldError(VgrFieldCode.invalidFormat));
      expect(VgrValidators.cep('010010000'), const VgrFieldError(VgrFieldCode.invalidFormat));
    });
  });

  group('VgrValidators.positiveNumber — mirrors z.number().positive()', () {
    test('accepts positive numbers, rejects zero/negative/garbage', () {
      expect(VgrValidators.positiveNumber('3000'), isNull);
      expect(VgrValidators.positiveNumber('0.5'), isNull);
      expect(VgrValidators.positiveNumber('0'), const VgrFieldError(VgrFieldCode.invalidValue));
      expect(VgrValidators.positiveNumber('-1'), const VgrFieldError(VgrFieldCode.invalidValue));
      expect(VgrValidators.positiveNumber('abc'), const VgrFieldError(VgrFieldCode.invalidValue));
    });
  });

  group('VgrValidators.validate (form helper)', () {
    test('returns the first error per field and nothing for valid fields', () {
      final errors = VgrValidators.validate({
        'email': ('', [VgrValidators.email]),
        'taxId': ('529.982.247-25', [VgrValidators.brTaxId]),
        'cep': ('123', [VgrValidators.cep]),
      });
      expect(errors, {
        'email': const VgrFieldError(VgrFieldCode.required),
        'cep': const VgrFieldError(VgrFieldCode.invalidFormat),
      });
    });
  });

  group('VgrValidators.minLength — mirrors z.string().min(n) (e.g. freezeReasonDto, decision 141)', () {
    test('shorter than n after trimming → TOO_SHORT with the minimum as param', () {
      expect(VgrValidators.minLength(3)('ab'), const VgrFieldError(VgrFieldCode.tooShort, {'min': '3'}));
      expect(VgrValidators.minLength(3)(' ab '), const VgrFieldError(VgrFieldCode.tooShort, {'min': '3'}));
    });

    test('exactly n or longer passes', () {
      expect(VgrValidators.minLength(3)('abc'), isNull);
      expect(VgrValidators.minLength(3)('Writ 123/2026'), isNull);
    });

    test('blank is REQUIRED, not TOO_SHORT', () {
      expect(VgrValidators.minLength(3)(''), const VgrFieldError(VgrFieldCode.required));
    });
  });

  group('VgrValidators.isoDate — mirrors the YYYY-MM-DD form of reports-admin.dto.ts from/to', () {
    test('accepts a calendar date', () {
      expect(VgrValidators.isoDate('2026-09-02'), isNull);
      expect(VgrValidators.isoDate('2024-02-29'), isNull);
    });

    test('rejects wrong shape or impossible dates → INVALID_FORMAT', () {
      for (final value in ['2026-9-2', '02/09/2026', '2026-13-01', '2026-02-30', '20260902', 'abc']) {
        expect(VgrValidators.isoDate(value), const VgrFieldError(VgrFieldCode.invalidFormat), reason: value);
      }
    });

    test('blank is REQUIRED', () {
      expect(VgrValidators.isoDate(''), const VgrFieldError(VgrFieldCode.required));
    });
  });
}
