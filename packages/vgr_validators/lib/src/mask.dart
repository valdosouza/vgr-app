import 'package:flutter/services.dart';

/// Keeps only the digits — what the API receives (decision 155).
String unmask(String value) => value.replaceAll(RegExp(r'\D'), '');

/// Input masks of the app (decision 157). The mask is UX only: it never
/// decides validity (that is `VgrValidators`) and it caps at the longest
/// domestic form even where the API rule is looser (phone accepts up to
/// 13 digits for a country code; the mask stops at 11).
enum VgrMask {
  /// `###.###.###-##` up to 11 digits, `##.###.###/####-##` beyond.
  cpfCnpj,

  /// `(##) ####-####` up to 10 digits, `(##) #####-####` at 11.
  phoneBr,

  /// `#####-###`.
  cep;

  String _pattern(int digitCount) => switch (this) {
        VgrMask.cpfCnpj => digitCount <= 11 ? '###.###.###-##' : '##.###.###/####-##',
        VgrMask.phoneBr => digitCount <= 10 ? '(##) ####-####' : '(##) #####-####',
        VgrMask.cep => '#####-###',
      };

  /// Applies the mask to the digits of [raw]; extra digits are dropped.
  String format(String raw) {
    final digits = unmask(raw);
    final pattern = _pattern(digits.length);
    final out = StringBuffer();
    var i = 0;
    for (final ch in pattern.split('')) {
      if (i >= digits.length) break;
      if (ch == '#') {
        out.write(digits[i++]);
      } else {
        out.write(ch);
      }
    }
    return out.toString();
  }
}

/// `TextInputFormatter` that reformats on every edit and parks the cursor at
/// the end (decision 157). Lives here, not in `vgr_widgets`, so the design
/// system carries no format rule; `VgrTextField.mask` is the only consumer.
class VgrMaskFormatter extends TextInputFormatter {
  const VgrMaskFormatter(this.mask);

  final VgrMask mask;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = mask.format(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
