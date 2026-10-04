import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

/// The pieces of the register factory (PS2 — decisions 217/220/221).
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  group('VgrPage.leading', () {
    testWidgets('renders before the title', (tester) async {
      await pump(
        tester,
        const VgrPage(title: 'Title', leading: Text('lead'), body: Text('body')),
      );

      final lead = tester.getTopLeft(find.text('lead'));
      final title = tester.getTopLeft(find.text('Title'));
      expect(lead.dx, lessThan(title.dx));
    });
  });

  group('VgrFormShell', () {
    testWidgets('back, delete and save each fire their own callback', (tester) async {
      final fired = <String>[];
      await pump(
        tester,
        VgrFormShell(
          title: 'Privilege',
          body: const Text('fields'),
          onBack: () => fired.add('back'),
          backTooltip: 'Back',
          onSave: () => fired.add('save'),
          saveLabel: 'Save',
          onDelete: () => fired.add('delete'),
          deleteTooltip: 'Delete',
        ),
      );

      expect(find.byType(AppBar), findsNothing);
      expect(find.text('fields'), findsOneWidget);
      await tester.tap(find.byKey(VgrFormShell.backKey));
      await tester.tap(find.byKey(VgrFormShell.deleteKey));
      await tester.tap(find.byKey(VgrFormShell.saveKey));
      expect(fired, ['back', 'delete', 'save']);
    });

    testWidgets('a null save or delete is not drawn at all', (tester) async {
      await pump(
        tester,
        VgrFormShell(
          title: 'Privilege',
          body: const Text('fields'),
          onBack: () {},
          backTooltip: 'Back',
          saveLabel: 'Save',
          deleteTooltip: 'Delete',
        ),
      );

      expect(find.byKey(VgrFormShell.saveKey), findsNothing);
      expect(find.byKey(VgrFormShell.deleteKey), findsNothing);
      expect(find.byKey(VgrFormShell.backKey), findsOneWidget);
    });

    testWidgets('busy spins the save button and silences both actions', (tester) async {
      final fired = <String>[];
      await pump(
        tester,
        VgrFormShell(
          title: 'Privilege',
          body: const Text('fields'),
          onBack: () {},
          backTooltip: 'Back',
          onSave: () => fired.add('save'),
          saveLabel: 'Save',
          onDelete: () => fired.add('delete'),
          deleteTooltip: 'Delete',
          busy: true,
        ),
      );

      expect(find.byType(VgrInlineProgress), findsOneWidget);
      await tester.tap(find.byKey(VgrFormShell.saveKey));
      await tester.tap(find.byKey(VgrFormShell.deleteKey));
      expect(fired, isEmpty);
    });
  });

  group('VgrPagingBar', () {
    Widget bar({
      required int page,
      required int pageCount,
      required ValueChanged<int> onPage,
      ValueChanged<int>? onSize,
    }) =>
        VgrPagingBar(
          page: page,
          pageCount: pageCount,
          summary: 'Page $page of $pageCount',
          onPageChanged: onPage,
          previousTooltip: 'Previous',
          nextTooltip: 'Next',
          pageSize: 20,
          pageSizes: const [10, 20, 50],
          onPageSizeChanged: onSize,
          pageSizeLabel: 'Per page',
        );

    testWidgets('moves one page each way inside the bounds', (tester) async {
      final pages = <int>[];
      await pump(tester, bar(page: 2, pageCount: 3, onPage: pages.add));

      expect(find.text('Page 2 of 3'), findsOneWidget);
      await tester.tap(find.byKey(VgrPagingBar.previousKey));
      await tester.tap(find.byKey(VgrPagingBar.nextKey));
      expect(pages, [1, 3]);
    });

    testWidgets('previous is off on the first page, next on the last', (tester) async {
      final pages = <int>[];
      await pump(tester, bar(page: 1, pageCount: 1, onPage: pages.add));

      await tester.tap(find.byKey(VgrPagingBar.previousKey));
      await tester.tap(find.byKey(VgrPagingBar.nextKey));
      expect(pages, isEmpty);
    });

    testWidgets('the size picker appears only with a handler and reports the pick', (tester) async {
      await pump(tester, bar(page: 1, pageCount: 1, onPage: (_) {}));
      expect(find.byKey(VgrPagingBar.pageSizeKey), findsNothing);

      final sizes = <int>[];
      await pump(tester, bar(page: 1, pageCount: 1, onPage: (_) {}, onSize: sizes.add));
      expect(find.text('Per page'), findsOneWidget);
      await tester.tap(find.byKey(VgrPagingBar.pageSizeKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('50').last);
      await tester.pumpAndSettle();
      expect(sizes, [50]);
    });
  });

  group('VgrSearchBar', () {
    testWidgets('Enter and the magnifier both submit the typed text', (tester) async {
      final submitted = <String>[];
      final controller = TextEditingController();
      await pump(
        tester,
        VgrSearchBar(
          controller: controller,
          label: 'Search',
          searchTooltip: 'Search',
          onSubmitted: submitted.add,
        ),
      );

      await tester.enterText(find.byKey(VgrSearchBar.fieldKey), 'ana');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.tap(find.byKey(VgrSearchBar.buttonKey));
      expect(submitted, ['ana', 'ana']);
    });
  });

  group('VgrEmptyState', () {
    testWidgets('shows the message', (tester) async {
      await pump(tester, const VgrEmptyState(message: 'Nothing here'));
      expect(find.text('Nothing here'), findsOneWidget);
    });
  });

  group('VgrTextField focus and read-only', () {
    testWidgets('a given focus node receives focus; read-only refuses typing', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      final controller = TextEditingController(text: 'fixed');
      await pump(
        tester,
        VgrTextField(controller: controller, label: 'Name', focusNode: node, readOnly: true),
      );

      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isTrue);
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    });
  });

  group('showVgrAlert / showVgrChoice', () {
    testWidgets('the alert closes on its single button', (tester) async {
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showVgrAlert(
              context,
              title: 'Oops',
              message: 'Broken',
              closeLabel: 'OK',
              closeKey: const Key('close'),
            ),
            child: const Text('open'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Broken'), findsOneWidget);
      await tester.tap(find.byKey(const Key('close')));
      await tester.pumpAndSettle();
      expect(find.text('Broken'), findsNothing);
    });

    testWidgets('the choice dialog returns the picked value, null when dismissed', (tester) async {
      final answers = <String?>[];
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => answers.add(await showVgrChoice<String>(
              context,
              title: 'Save?',
              message: 'Unsaved changes',
              choices: const [
                VgrChoice(value: 'cancel', label: 'Cancel'),
                VgrChoice(value: 'no', label: 'No'),
                VgrChoice(value: 'yes', label: 'Yes', primary: true),
              ],
            )),
            child: const Text('open'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5)); // outside the dialog
      await tester.pumpAndSettle();

      expect(answers, ['no', null]);
    });
  });
}
