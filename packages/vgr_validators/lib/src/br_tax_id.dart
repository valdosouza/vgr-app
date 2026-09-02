/// Brazilian tax id (CPF 11 digits / CNPJ 14 digits) check-digit validation.
/// Mirrors `api/src/modules/reward/br-tax-id.ts` function by function
/// (decision 155: both sides verify the check digits; decision 154: the
/// API file is the source of truth). Digits only — callers unmask first.
library;

bool _allSameDigit(String digits) => RegExp(r'^(\d)\1*$').hasMatch(digits);

int _mod11(String digits, List<int> weights) {
  var sum = 0;
  for (var i = 0; i < digits.length; i++) {
    sum += int.parse(digits[i]) * weights[i];
  }
  final rest = sum % 11;
  return rest < 2 ? 0 : 11 - rest;
}

bool isValidCpf(String value) {
  if (!RegExp(r'^\d{11}$').hasMatch(value) || _allSameDigit(value)) return false;
  final base = value.substring(0, 9);
  final d1 = _mod11(base, const [10, 9, 8, 7, 6, 5, 4, 3, 2]);
  final d2 = _mod11('$base$d1', const [11, 10, 9, 8, 7, 6, 5, 4, 3, 2]);
  return value == '$base$d1$d2';
}

bool isValidCnpj(String value) {
  if (!RegExp(r'^\d{14}$').hasMatch(value) || _allSameDigit(value)) return false;
  final base = value.substring(0, 12);
  final d1 = _mod11(base, const [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]);
  final d2 = _mod11('$base$d1', const [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]);
  return value == '$base$d1$d2';
}

/// Dispatches by length: 11 → CPF, 14 → CNPJ, anything else is invalid.
bool isValidBrTaxId(String value) {
  if (value.length == 11) return isValidCpf(value);
  if (value.length == 14) return isValidCnpj(value);
  return false;
}
