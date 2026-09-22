import 'package:flutter/material.dart';

import 'vgr_layout.dart';
import 'vgr_text.dart';

/// A page rendered INSIDE the admin shell's router outlet (decision 215).
///
/// Same parameters as [VgrScaffold] on purpose — moving a screen into
/// the shell is a rename — but no `AppBar`: the shell already owns the
/// top bar, so the title becomes a content header. Still a [Scaffold]
/// underneath, so a floating action button and snack bars keep working
/// exactly as they did on a full-screen page.
class VgrPage extends StatelessWidget {
  const VgrPage({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.padded = true,
    this.floatingAction,
  });

  final String title;
  final Widget body;

  /// Header actions — already-built Vgr widgets, never raw ones.
  final List<Widget> actions;

  /// Content padding on by default, as on [VgrScaffold].
  final bool padded;
  final Widget? floatingAction;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(child: VgrText.headline(title, key: const Key('vgr-page-title'))),
                  ...actions,
                ],
              ),
            ),
            const VgrDivider(),
            Expanded(child: padded ? VgrPadding.screen(child: body) : body),
          ],
        ),
        floatingActionButton: floatingAction,
      );
}
