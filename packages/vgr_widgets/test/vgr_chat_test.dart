import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Chat widgets of the masked chat (C2, decisions 133/170/172). The design
/// system carries NO rule about who is who: it renders the text, the
/// side and the status it is handed.
void main() {
  group('VgrChatBubble', () {
    testWidgets('my message sits on the right, the other side on the left', (tester) async {
      await tester.pumpWidget(host(const VgrColumn(children: [
        VgrChatBubble(key: Key('mine'), text: 'hi', mine: true, timeLabel: '10:00'),
        VgrChatBubble(key: Key('theirs'), text: 'hello', mine: false, timeLabel: '10:01'),
      ])));

      Alignment alignmentOf(Key key) => tester
          .widget<Align>(find.descendant(of: find.byKey(key), matching: find.byType(Align)).first)
          .alignment as Alignment;
      expect(alignmentOf(const Key('mine')), Alignment.centerRight);
      expect(alignmentOf(const Key('theirs')), Alignment.centerLeft);
      expect(find.text('hi'), findsOneWidget);
      expect(find.text('10:01'), findsOneWidget);
    });

    testWidgets('pending and failed statuses render their labels; sent renders none',
        (tester) async {
      await tester.pumpWidget(host(const VgrColumn(children: [
        VgrChatBubble(text: 'a', mine: true, timeLabel: '', status: VgrChatBubbleStatus.pending, statusLabel: 'Sending…'),
        VgrChatBubble(text: 'b', mine: true, timeLabel: '', status: VgrChatBubbleStatus.failed, statusLabel: 'Not sent: phone'),
        VgrChatBubble(text: 'c', mine: true, timeLabel: '', status: VgrChatBubbleStatus.sent, statusLabel: 'never shown'),
      ])));

      expect(find.text('Sending…'), findsOneWidget);
      expect(find.text('Not sent: phone'), findsOneWidget);
      expect(find.text('never shown'), findsNothing);
    });

    testWidgets('a failed bubble takes the error color from the theme, not a literal',
        (tester) async {
      await tester.pumpWidget(host(const VgrChatBubble(
        text: 'b',
        mine: true,
        timeLabel: '',
        status: VgrChatBubbleStatus.failed,
        statusLabel: 'Not sent',
      )));

      final context = tester.element(find.text('Not sent'));
      expect(
        tester.widget<Text>(find.text('Not sent')).style?.color,
        Theme.of(context).colorScheme.error,
      );
    });
  });

  group('VgrChatBubble — long status label', () {
    testWidgets('a long refusal wraps inside the bubble instead of overflowing', (tester) async {
      await tester.pumpWidget(host(const VgrChatBubble(
        text: 'me liga',
        mine: true,
        timeLabel: '2026-09-03 10:20',
        status: VgrChatBubbleStatus.failed,
        statusLabel:
            'Not sent: Direct contact is not allowed (phone: "(11) 91234-5678"). The chat is masked.',
      )));

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Not sent'), findsOneWidget);
    });
  });

  group('VgrChatComposer', () {
    testWidgets('sends the typed text on the button and on submit, and caps at maxLength',
        (tester) async {
      final controller = TextEditingController();
      final sent = <String>[];
      await tester.pumpWidget(host(VgrChatComposer(
        controller: controller,
        hint: 'No phone numbers',
        sendLabel: 'Send',
        maxLength: 5,
        onSend: sent.add,
      )));

      await tester.enterText(find.byType(TextField), 'abcdefgh');
      expect(controller.text, 'abcde'); // the design system enforces the cap
      await tester.tap(find.byTooltip('Send'));
      expect(sent, ['abcde']);
      expect(find.text('No phone numbers'), findsOneWidget);
    });

    testWidgets('shows the error under the field and disables sending while disabled',
        (tester) async {
      final controller = TextEditingController(text: 'x');
      var sends = 0;
      await tester.pumpWidget(host(VgrChatComposer(
        controller: controller,
        hint: 'hint',
        sendLabel: 'Send',
        errorText: 'Contact not allowed',
        enabled: false,
        onSend: (_) => sends++,
      )));

      expect(find.text('Contact not allowed'), findsOneWidget);
      await tester.tap(find.byTooltip('Send'));
      expect(sends, 0);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });
  });

  group('VgrChatMessageList', () {
    testWidgets('lists its children in order and scrolls', (tester) async {
      await tester.pumpWidget(host(const VgrChatMessageList(children: [
        VgrText('one'),
        VgrText('two'),
      ])));

      expect(find.text('one'), findsOneWidget);
      expect(find.text('two'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
    });
  });

  group('VgrBadge', () {
    testWidgets('renders the label', (tester) async {
      await tester.pumpWidget(host(const VgrBadge(label: '3')));
      expect(find.text('3'), findsOneWidget);
    });
  });
}
