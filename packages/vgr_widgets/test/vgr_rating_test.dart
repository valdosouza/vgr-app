import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Helper rating star control (decision 133; RT2 — decisions 182-184). One
/// widget covers both read and write: [VgrRating.onChanged] null is the
/// disabled/read-only convention every Vgr* widget already follows
/// (`VgrPrimaryButton(onPressed: null)`).
void main() {
  group('VgrRating', () {
    testWidgets('read-only (onChanged null): every star key exists but tapping never calls back',
        (tester) async {
      var calls = 0;
      await tester.pumpWidget(host(VgrRating(value: 3, onChanged: null)));

      for (var i = 1; i <= 5; i++) {
        expect(find.byKey(Key('rating-star-$i')), findsOneWidget);
      }
      await tester.tap(find.byKey(const Key('rating-star-5')));
      await tester.tap(find.byKey(const Key('rating-star-1')));
      expect(calls, 0);
    });

    testWidgets('interactive: tapping star i reports exactly i', (tester) async {
      int? reported;
      await tester.pumpWidget(host(VgrRating(value: null, onChanged: (v) => reported = v)));

      await tester.tap(find.byKey(const Key('rating-star-3')));
      expect(reported, 3);

      await tester.tap(find.byKey(const Key('rating-star-5')));
      expect(reported, 5);
    });

    testWidgets('value paints stars 1..value as filled and the rest as outline',
        (tester) async {
      await tester.pumpWidget(host(VgrRating(value: 3, onChanged: (_) {})));

      Icon iconAt(int i) =>
          tester.widget<Icon>(find.descendant(of: find.byKey(Key('rating-star-$i')), matching: find.byType(Icon)));

      expect(iconAt(1).icon, Icons.star);
      expect(iconAt(3).icon, Icons.star);
      expect(iconAt(4).icon, Icons.star_border);
      expect(iconAt(5).icon, Icons.star_border);
    });

    testWidgets('null value paints every star as outline (not yet rated)', (tester) async {
      await tester.pumpWidget(host(VgrRating(value: null, onChanged: (_) {})));

      Icon iconAt(int i) =>
          tester.widget<Icon>(find.descendant(of: find.byKey(Key('rating-star-$i')), matching: find.byType(Icon)));

      for (var i = 1; i <= 5; i++) {
        expect(iconAt(i).icon, Icons.star_border);
      }
    });
  });
}
