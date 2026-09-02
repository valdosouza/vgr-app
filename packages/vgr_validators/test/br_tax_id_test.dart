import 'package:flutter_test/flutter_test.dart';
import 'package:vgr_validators/vgr_validators.dart';

/// Mirrors `api/src/modules/reward/__tests__/br-tax-id.spec.ts` case by
/// case (decisions 154/155) — keep the fixtures identical on both sides.
void main() {
  group('isValidCpf', () {
    test('accepts a CPF with correct check digits', () {
      expect(isValidCpf('52998224725'), isTrue);
    });

    test('rejects a CPF whose last check digit is wrong', () {
      expect(isValidCpf('52998224726'), isFalse);
    });

    test('rejects a CPF whose first check digit is wrong', () {
      expect(isValidCpf('52998224735'), isFalse);
    });

    test('rejects the classic all-same-digit sequences', () {
      for (final d in '0123456789'.split('')) {
        expect(isValidCpf(d * 11), isFalse, reason: d * 11);
      }
    });

    test('rejects anything that is not exactly 11 digits (unmask first)', () {
      expect(isValidCpf('529.982.247-25'), isFalse);
      expect(isValidCpf('5299822472'), isFalse);
      expect(isValidCpf('529982247250'), isFalse);
      expect(isValidCpf(''), isFalse);
    });
  });

  group('isValidCnpj', () {
    test('accepts a CNPJ with correct check digits', () {
      expect(isValidCnpj('11222333000181'), isTrue);
    });

    test('rejects a CNPJ whose check digits are wrong', () {
      expect(isValidCnpj('11222333000182'), isFalse);
      expect(isValidCnpj('11222333000191'), isFalse);
    });

    test('rejects all-same-digit sequences', () {
      for (final d in '0123456789'.split('')) {
        expect(isValidCnpj(d * 14), isFalse, reason: d * 14);
      }
    });

    test('rejects anything that is not exactly 14 digits', () {
      expect(isValidCnpj('11.222.333/0001-81'), isFalse);
      expect(isValidCnpj('1122233300018'), isFalse);
    });
  });

  group('isValidBrTaxId', () {
    test('dispatches by length: 11 → CPF, 14 → CNPJ', () {
      expect(isValidBrTaxId('52998224725'), isTrue);
      expect(isValidBrTaxId('11222333000181'), isTrue);
    });

    test('rejects 12/13-digit strings', () {
      expect(isValidBrTaxId('529982247251'), isFalse);
      expect(isValidBrTaxId('5299822472511'), isFalse);
    });
  });
}
