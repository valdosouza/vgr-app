import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vgr_admin/app/shared/register/page_summary.dart';

import '../../../helpers/pump_localized.dart';

PagedResult<int> _total(int total) => PagedResult(items: const [], page: 1, pageSize: 20, total: total);

/// The pager summary counts records with the right plural form — "1 registros"
/// was on screen in the browser test of 2026-10-04.
void main() {
  testWidgets('one, zero and many — in English and in Portuguese', (tester) async {
    await pumpLocalized(
      tester,
      Builder(builder: (context) {
        context.locale; // rebuild on the switch below, as LocaleRefresh does in the app
        return Column(children: [
          Text(pageSummary(_total(0))),
          Text(pageSummary(_total(1))),
          Text(pageSummary(_total(2))),
        ]);
      }),
    );
    expect(find.text('Page 1 of 1 · 0 records'), findsOneWidget);
    expect(find.text('Page 1 of 1 · 1 record'), findsOneWidget);
    expect(find.text('Page 1 of 1 · 2 records'), findsOneWidget);

    await tester.element(find.byType(Column)).setLocale(const Locale('pt', 'BR'));
    await tester.pumpAndSettle();
    expect(find.text('Página 1 de 1 · 0 registros'), findsOneWidget);
    expect(find.text('Página 1 de 1 · 1 registro'), findsOneWidget);
    expect(find.text('Página 1 de 1 · 2 registros'), findsOneWidget);
  });
}
