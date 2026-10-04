import 'package:flutter/widgets.dart';

import 'vgr_button.dart';
import 'vgr_icon.dart';
import 'vgr_layout.dart';
import 'vgr_page.dart';

/// The frame of a register form inside the admin shell (decision 217 —
/// setes' `SetesFormShell`): back · title · delete · save, over a
/// scrolling body. A [VgrPage] underneath, so it never draws an app bar of
/// its own (the shell owns that).
///
/// An action whose callback is null is not drawn at all: a new record has
/// nothing to delete, and a user without the privilege to change a record
/// sees it read-only, with no save. Labels arrive translated — the design
/// system translates nothing.
class VgrFormShell extends StatelessWidget {
  const VgrFormShell({
    super.key,
    required this.title,
    required this.body,
    required this.onBack,
    required this.backTooltip,
    required this.saveLabel,
    required this.deleteTooltip,
    this.onSave,
    this.onDelete,
    this.busy = false,
  });

  final String title;
  final Widget body;

  final VoidCallback onBack;
  final String backTooltip;

  final VoidCallback? onSave;
  final String saveLabel;

  final VoidCallback? onDelete;
  final String deleteTooltip;

  /// A save or delete is in flight: the save button spins and both
  /// actions stop answering, so a double click cannot fire twice.
  final bool busy;

  static const backKey = Key('form-shell-back');
  static const saveKey = Key('form-shell-save');
  static const deleteKey = Key('form-shell-delete');

  @override
  Widget build(BuildContext context) => VgrPage(
        title: title,
        leading: VgrIconButton(
          key: backKey,
          icon: VgrIconName.back,
          tooltip: backTooltip,
          onPressed: onBack,
        ),
        actions: [
          if (onDelete != null)
            VgrIconButton(
              key: deleteKey,
              icon: VgrIconName.delete,
              tooltip: deleteTooltip,
              onPressed: busy ? null : onDelete,
            ),
          if (onSave != null) ...[
            const VgrGap.hSm(),
            VgrPrimaryButton(
              key: saveKey,
              label: saveLabel,
              icon: VgrIconName.save,
              busy: busy,
              onPressed: onSave,
            ),
          ],
        ],
        body: VgrScrollView(child: body),
      );
}
