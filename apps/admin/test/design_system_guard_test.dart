import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guard for decision 133: **no raw Flutter widget is used directly in a
/// screen** — everything goes through `packages/vgr_widgets` as a `Vgr*`
/// widget, so an obsolete or unmaintained widget can be swapped without
/// touching the rest of the system.
///
/// A written rule that nothing checks decays into a suggestion; the
/// `vgr_widgets` package itself is proof — its pubspec has carried this
/// rule since day one while the package sat empty and every screen used
/// raw widgets. This test is what makes the rule real.
///
/// Scope: screen/presentation code of `apps/admin` and `packages/core`.
/// The design system itself is exempt — wrapping raw widgets is precisely
/// its job — and so are tests, which legitimately pump raw widgets.
void main() {
  /// Widgets that must never appear outside the design system. The list is
  /// what the panel actually uses; add to it when a new one shows up
  /// rather than making the check clever.
  const banned = <String>[
    'Text', 'SelectableText', 'TextField', 'TextFormField',
    'ElevatedButton', 'TextButton', 'OutlinedButton', 'IconButton',
    'FloatingActionButton', 'Scaffold', 'AppBar', 'Card', 'ListTile',
    'CheckboxListTile', 'Checkbox', 'SwitchListTile', 'Switch',
    'CircularProgressIndicator', 'LinearProgressIndicator', 'Icon',
    'SizedBox', 'Padding', 'Column', 'Row', 'Center', 'Divider', 'ListView',
    'AlertDialog', 'SnackBar', 'DropdownButton', 'DropdownButtonFormField',
    'ExpansionTile', 'PopupMenuButton', 'SingleChildScrollView', 'Expanded',
    'StatefulBuilder',
  ];

  final roots = [
    Directory('lib'),
    Directory('../../packages/core/lib'),
  ];

  test('no screen uses a raw Flutter widget (decision 133)', () {
    final offenders = <String>[];

    for (final root in roots) {
      if (!root.existsSync()) continue;
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        // The design system is where raw widgets legitimately live.
        if (entity.path.replaceAll('\\', '/').contains('/vgr_widgets/')) continue;

        final lines = entity.readAsLinesSync();
        for (var index = 0; index < lines.length; index++) {
          final line = lines[index];
          final code = line.split('//').first;
          if (code.trim().isEmpty) continue;

          for (final widget in banned) {
            // Constructor call or type reference: `Text(`, `const Text(`,
            // `<Checkbox>`. `VgrText(` must not match, hence the boundary.
            final pattern = RegExp('(?<![A-Za-z0-9_])$widget\\s*[(<]');
            if (pattern.hasMatch(code)) {
              offenders.add('${entity.path}:${index + 1} -> $widget');
              break;
            }
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Raw Flutter widgets found in screen code. Decision 133 requires a Vgr* '
          'widget from packages/vgr_widgets instead — add one there if it is missing:\n'
          '${offenders.join('\n')}',
    );
  });
}
