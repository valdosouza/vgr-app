import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Direction-sighting compass picker (decision 133; DS2 — decisions
/// 200-207). One widget covers both read AND write, mirroring
/// `VgrRating`'s exact convention: [VgrCompass.onChanged] null is the
/// disabled/read-only convention every Vgr* widget already follows
/// (`VgrPrimaryButton(onPressed: null)`). Values are the plain 8 wire
/// codes, never a `Direction` enum — this package depends on nothing but
/// `vgr_validators` (no `packages/core`, no business logic).
void main() {
  group('VgrCompass', () {
    testWidgets('renders exactly the 8 compass points with stable keys',
        (tester) async {
      await tester.pumpWidget(host(VgrCompass(value: null, onChanged: (_) {})));

      for (final point in const ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW']) {
        expect(find.byKey(Key('direction-$point')), findsOneWidget);
      }
    });

    testWidgets('read-only (onChanged null): tapping any button never calls back',
        (tester) async {
      var calls = 0;
      await tester.pumpWidget(host(VgrCompass(value: 'N', onChanged: null)));

      await tester.tap(find.byKey(const Key('direction-N')));
      await tester.tap(find.byKey(const Key('direction-SW')));

      expect(calls, 0);
    });

    testWidgets('interactive: tapping a point reports exactly its code, immediately '
        '— no confirm step', (tester) async {
      String? reported;
      await tester.pumpWidget(host(VgrCompass(value: null, onChanged: (v) => reported = v)));

      await tester.tap(find.byKey(const Key('direction-SE')));
      expect(reported, 'SE');

      await tester.tap(find.byKey(const Key('direction-W')));
      expect(reported, 'W');
    });

    testWidgets('every one of the 8 points is independently tappable', (tester) async {
      final reported = <String>[];
      await tester.pumpWidget(host(VgrCompass(value: null, onChanged: reported.add)));

      for (final point in const ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW']) {
        await tester.tap(find.byKey(Key('direction-$point')));
      }

      expect(reported, ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW']);
    });
  });
}
