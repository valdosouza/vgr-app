import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_localized.dart';

/// The real catalogs, through `failureText`. `RATING_CLOSED` carries the
/// API's `params.reason` (`open` | `hidden`, decisions 181/162), and each
/// reason must read as a full sentence — the catalog used to interpolate
/// the raw token, so users saw "(open)".
///
/// Also pins the shape `failureText` relies on: a variant map under
/// `core.errors` must carry an `other` leaf, because easy_localization
/// throws when a key resolves to a map node instead of a string.
void main() {
  const catalogs = ['assets/translations/en-US.json', 'assets/translations/pt-BR.json'];

  for (final file in catalogs) {
    test('$file: every variant map under core.errors carries an `other` leaf', () {
      final json = jsonDecode(File(file).readAsStringSync()) as Map<String, dynamic>;
      final errors = (json['core'] as Map<String, dynamic>)['errors'] as Map<String, dynamic>;

      final missing = [
        for (final entry in errors.entries)
          if (entry.value is Map<String, dynamic> && (entry.value as Map)['other'] is! String)
            entry.key,
      ];

      expect(missing, isEmpty, reason: 'variant maps without an `other` leaf');
    });
  }

  testWidgets('RATING_CLOSED reads as a sentence for each reason, in both locales', (tester) async {
    const probe = Key('locale-probe');
    await pumpLocalized(tester, const SizedBox.shrink(key: probe));

    const open = Failure(message: 'The report is not resolved yet', code: 'RATING_CLOSED', params: {'reason': 'open'});
    const hidden = Failure(message: 'The report is hidden', code: 'RATING_CLOSED', params: {'reason': 'hidden'});

    expect(failureText(open), 'You can only rate after the case is closed — this one is still open.');
    expect(failureText(hidden), 'This case has been hidden and can no longer be rated.');

    await tester.element(find.byKey(probe)).setLocale(const Locale('pt', 'BR'));
    await tester.pumpAndSettle();

    expect(failureText(open), 'Só é possível avaliar depois que o caso for encerrado — este ainda está aberto.');
    expect(failureText(hidden), 'Este caso foi ocultado e não pode mais ser avaliado.');
  });
}
