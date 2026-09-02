import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vgr_validators/vgr_validators.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('VgrTextField.mask (decision 157)', () {
    testWidgets('applies the named mask while typing and exposes no formatter', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(host(
        VgrTextField(controller: controller, label: 'CPF', mask: VgrMask.cpfCnpj),
      ));

      await tester.enterText(find.byType(TextField), '52998224725');
      expect(controller.text, '529.982.247-25');
      expect(unmask(controller.text), '52998224725');
    });

    testWidgets('without a mask, the number keyboard still filters to digits', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(host(
        VgrTextField(controller: controller, label: 'N', keyboard: VgrKeyboard.number),
      ));

      await tester.enterText(find.byType(TextField), '12a3');
      expect(controller.text, '123');
    });
  });

  group('VgrText', () {
    testWidgets('renders the text and resolves the role against the theme', (tester) async {
      await tester.pumpWidget(host(const VgrText.title('Hello')));

      expect(find.text('Hello'), findsOneWidget);
      final style = tester.widget<Text>(find.byType(Text)).style;
      final expected = Theme.of(tester.element(find.text('Hello'))).textTheme.titleMedium;
      expect(style?.fontSize, expected?.fontSize);
    });

    testWidgets('error role takes its color from the theme, not a literal', (tester) async {
      await tester.pumpWidget(host(const VgrText.error('Boom')));

      final context = tester.element(find.text('Boom'));
      expect(
        tester.widget<Text>(find.byType(Text)).style?.color,
        Theme.of(context).colorScheme.error,
      );
    });
  });

  group('VgrPrimaryButton', () {
    testWidgets('shows a spinner and refuses taps while busy', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(
        VgrPrimaryButton(label: 'Save', onPressed: () => taps++, busy: true),
      ));

      expect(find.byType(VgrInlineProgress), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      await tester.tap(find.byType(VgrPrimaryButton));
      expect(taps, 0);
    });

    testWidgets('shows the label and fires the callback when idle', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(
        VgrPrimaryButton(label: 'Save', onPressed: () => taps++),
      ));

      await tester.tap(find.text('Save'));
      expect(taps, 1);
    });
  });

  group('VgrTextField', () {
    testWidgets('wires label, error and obscure through to the input', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(host(
        VgrTextField(
          controller: controller,
          label: 'Password',
          errorText: 'Too short',
          obscure: true,
        ),
      ));

      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Too short'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isTrue);
    });
  });

  group('VgrIcon', () {
    test('every semantic name maps to an icon — no name can be added and forgotten', () {
      for (final name in VgrIconName.values) {
        expect(VgrIcon.dataOf(name), isA<IconData>());
      }
    });
  });

  group('VgrCheckboxTile', () {
    testWidgets('reports the new value without the caller handling nulls', (tester) async {
      bool? received;
      await tester.pumpWidget(host(
        VgrCheckboxTile(label: 'Keep', value: false, onChanged: (v) => received = v),
      ));

      await tester.tap(find.byType(Checkbox));
      expect(received, isTrue);
    });
  });

  group('showVgrConfirm', () {
    testWidgets('returns false when cancelled — destructive callers default to "no"',
        (tester) async {
      bool? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => VgrPrimaryButton(
            label: 'Delete',
            onPressed: () async {
              result = await showVgrConfirm(
                context,
                title: 'Confirm',
                message: 'Delete?',
                confirmLabel: 'Yes',
                cancelLabel: 'No',
                destructive: true,
              );
            },
          ),
        ),
      ));

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });
  });
}
