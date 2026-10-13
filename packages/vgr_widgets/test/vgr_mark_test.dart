import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

Widget _app(Widget child, {ThemeData? theme}) =>
    MaterialApp(theme: theme ?? VgrTheme.light(), home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('the symbol keeps its proportion and is silent next to a name', (tester) async {
    await tester.pumpWidget(_app(const VgrSymbol(height: 30)));
    final size = tester.getSize(find.byType(VgrSymbol));
    expect(size.height, 30);
    expect(size.width, closeTo(30 * VgrSymbol.aspectRatio, 0.01));
    expect(find.bySemanticsLabel('VGR'), findsNothing);
  });

  testWidgets('the logo is read as one name', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(const VgrLogo()));
    expect(find.bySemanticsLabel('VGR — Vigilância e Recompensa'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the main button is the action teal; the panic trigger is red', (tester) async {
    Color background(String label) {
      final button = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, label));
      final theme = Theme.of(tester.element(find.text(label)));
      final style = button.style?.merge(theme.elevatedButtonTheme.style) ?? theme.elevatedButtonTheme.style!;
      return style.backgroundColor!.resolve({})!;
    }

    await tester.pumpWidget(_app(Column(mainAxisSize: MainAxisSize.min, children: [
      VgrPrimaryButton(label: 'Enviar', onPressed: () {}),
      VgrPrimaryButton(label: 'Preciso de ajuda agora', onPressed: () {}, danger: true),
    ])));
    expect(background('Enviar'), VgrColors.light.action);
    expect(background('Preciso de ajuda agora'), VgrColors.light.danger);
  });

  testWidgets('the panic icon is the one red icon of the app bar', (tester) async {
    await tester.pumpWidget(_app(Row(mainAxisSize: MainAxisSize.min, children: [
      VgrIconButton(icon: VgrIconName.panic, onPressed: () {}, tooltip: 'Botão de pânico'),
      VgrIconButton(icon: VgrIconName.person, onPressed: () {}, tooltip: 'Conta'),
    ]), theme: VgrTheme.dark()));
    final buttons = tester.widgetList<IconButton>(find.byType(IconButton)).toList();
    expect(buttons[0].color, VgrColors.dark.danger);
    expect(buttons[1].color, isNull);
  });

  testWidgets('the home screens show the mark beside the title', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: VgrTheme.light(),
      home: const VgrScaffold(title: 'Por perto', showMark: true, body: SizedBox()),
    ));
    expect(find.byType(VgrSymbol), findsOneWidget);
    expect(find.text('Por perto'), findsOneWidget);
  });
}
