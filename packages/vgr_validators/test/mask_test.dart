import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vgr_validators/vgr_validators.dart';

/// The mask is UX only (decision 157): it never decides validity — that is
/// the validators' job — and the screen sends `unmask(text)` to the API,
/// which accepts digits only (decision 155).
void main() {
  group('unmask', () {
    test('keeps only digits', () {
      expect(unmask('529.982.247-25'), '52998224725');
      expect(unmask('(11) 99999-8888'), '11999998888');
      expect(unmask(''), '');
    });
  });

  group('VgrMask.format', () {
    test('cpfCnpj switches pattern at the 12th digit and caps at 14', () {
      expect(VgrMask.cpfCnpj.format('529'), '529');
      expect(VgrMask.cpfCnpj.format('5299822'), '529.982.2');
      expect(VgrMask.cpfCnpj.format('52998224725'), '529.982.247-25');
      expect(VgrMask.cpfCnpj.format('112223330001'), '11.222.333/0001');
      expect(VgrMask.cpfCnpj.format('11222333000181'), '11.222.333/0001-81');
      expect(VgrMask.cpfCnpj.format('112223330001819'), '11.222.333/0001-81');
    });

    test('phoneBr uses 8-digit or 9-digit local number and caps at 11', () {
      expect(VgrMask.phoneBr.format('11'), '(11');
      expect(VgrMask.phoneBr.format('1133334444'), '(11) 3333-4444');
      expect(VgrMask.phoneBr.format('11999998888'), '(11) 99999-8888');
      expect(VgrMask.phoneBr.format('119999988889'), '(11) 99999-8888');
    });

    test('cep is #####-### and caps at 8', () {
      expect(VgrMask.cep.format('01001'), '01001');
      expect(VgrMask.cep.format('01001000'), '01001-000');
      expect(VgrMask.cep.format('010010009'), '01001-000');
    });

    test('non-digits in the input are ignored', () {
      expect(VgrMask.cep.format('01001-000'), '01001-000');
      expect(VgrMask.cpfCnpj.format('abc529'), '529');
    });
  });

  group('VgrMaskFormatter', () {
    TextEditingValue type(VgrMask mask, String old, String typed) =>
        VgrMaskFormatter(mask).formatEditUpdate(
          TextEditingValue(text: old),
          TextEditingValue(text: typed, selection: TextSelection.collapsed(offset: typed.length)),
        );

    test('formats as the user types and keeps the cursor at the end', () {
      final v = type(VgrMask.cpfCnpj, '529.982', '529.9822');
      expect(v.text, '529.982.2');
      expect(v.selection.baseOffset, v.text.length);
    });

    test('pasting a masked value normalises it', () {
      expect(type(VgrMask.phoneBr, '', '+55 (11) 99999-8888').text, '(55) 11999-9988');
      expect(type(VgrMask.cep, '', '01001-000').text, '01001-000');
    });

    test('deleting a separator removes the digit before it', () {
      // User had '529.982' and pressed backspace: the framework hands us '529.98'.
      expect(type(VgrMask.cpfCnpj, '529.982', '529.98').text, '529.98');
      // User had '01001-0' and pressed backspace over the '-': '01001' comes in.
      expect(type(VgrMask.cep, '01001-0', '01001').text, '01001');
    });
  });
}
