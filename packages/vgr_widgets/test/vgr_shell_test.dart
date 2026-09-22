import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, double width, Widget child) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: child));
  }

  group('VgrResponsive (decision 218 — setes breakpoints 850/1100)', () {
    const widget = VgrResponsive(
      mobile: Text('mobile'),
      tablet: Text('tablet'),
      desktop: Text('desktop'),
    );

    testWidgets('849 → mobile', (tester) async {
      await pumpAt(tester, 849, widget);
      expect(find.text('mobile'), findsOneWidget);
    });

    testWidgets('850 → tablet when given', (tester) async {
      await pumpAt(tester, 850, widget);
      expect(find.text('tablet'), findsOneWidget);
    });

    testWidgets('850 → mobile when no tablet variant', (tester) async {
      await pumpAt(tester, 850, const VgrResponsive(mobile: Text('mobile'), desktop: Text('desktop')));
      expect(find.text('mobile'), findsOneWidget);
    });

    testWidgets('1100 → desktop', (tester) async {
      await pumpAt(tester, 1100, widget);
      expect(find.text('desktop'), findsOneWidget);
    });
  });

  group('VgrPage', () {
    testWidgets('renders the title as a content header, no AppBar, and keeps the FAB', (tester) async {
      await pumpAt(
        tester,
        1200,
        VgrPage(
          title: 'Users',
          actions: const [Text('action')],
          floatingAction: VgrFloatingAddButton(onPressed: () {}, tooltip: 'New'),
          body: const Text('body'),
        ),
      );

      expect(find.byKey(const Key('vgr-page-title')), findsOneWidget);
      expect(find.text('Users'), findsOneWidget);
      expect(find.text('action'), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });

  group('VgrSidebarLayout / VgrNavColumn', () {
    testWidgets('columns keep their width and the content takes the rest', (tester) async {
      await pumpAt(
        tester,
        1200,
        const VgrSidebarLayout(
          sidebars: [
            VgrNavColumn(width: 200, children: [Text('m')]),
            VgrNavColumn(width: 240, level: 1, children: [Text('s')]),
          ],
          content: SizedBox.expand(key: Key('content')),
        ),
      );

      expect(tester.getSize(find.byType(VgrNavColumn).first).width, 200);
      expect(tester.getSize(find.byType(VgrNavColumn).last).width, 240);
      expect(tester.getSize(find.byKey(const Key('content'))).width, 1200 - 440);
    });
  });

  testWidgets('VgrListTile.selected reaches the ListTile', (tester) async {
    await pumpAt(tester, 800, const Scaffold(body: VgrListTile(title: 'x', selected: true)));
    expect(tester.widget<ListTile>(find.byType(ListTile)).selected, isTrue);
  });

  testWidgets('VgrScaffold.drawer gives the app bar a hamburger', (tester) async {
    await pumpAt(
      tester,
      600,
      const VgrScaffold(title: 't', body: Text('b'), drawer: VgrDrawer(children: [Text('d')])),
    );
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('d'), findsOneWidget);
  });
}
