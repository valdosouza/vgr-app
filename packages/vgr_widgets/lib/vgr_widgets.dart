/// Design system of the VGR apps (decision 133).
///
/// **No raw Flutter widget is used directly in a screen.** Everything is
/// encapsulated here as a `Vgr*` widget, so an obsolete or unmaintained
/// widget can be swapped without touching the rest of the system — the
/// same rule the setes-app follows with its `Setes*` prefix.
///
/// Enforced by `apps/admin/test/design_system_guard_test.dart`, which
/// fails the build when a banned widget appears in screen code.
library;

export 'src/vgr_button.dart';
export 'src/vgr_chat.dart';
export 'src/vgr_feedback.dart';
export 'src/vgr_field.dart';
export 'src/vgr_icon.dart';
export 'src/vgr_layout.dart';
export 'src/vgr_menu.dart';
export 'src/vgr_photo.dart';
export 'src/vgr_progress.dart';
export 'src/vgr_scaffold.dart';
export 'src/vgr_text.dart';
export 'src/vgr_tile.dart';
