import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

/// The scaffold keeps the body clear of the system's bottom inset
/// (Android navigation bar), so foot-of-screen controls — the chat
/// composer first of all — stay reachable.
void main() {
  testWidgets('VgrScaffold keeps the body above the bottom system inset', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(bottom: 48)),
        child: VgrScaffold(
          title: 't',
          padded: false,
          body: Container(key: const Key('body')),
        ),
      ),
    ));

    final bodyRect = tester.getRect(find.byKey(const Key('body')));
    final screen = tester.getRect(find.byType(Scaffold));
    expect(screen.bottom - bodyRect.bottom, 48);
  });
}
