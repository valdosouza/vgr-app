import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guard for decision 221: **screens talk back to the user only through
/// the feedback bridge** (`lib/app/shared/feedback/`) — `showSuccessFeedback`,
/// `showFailureFeedback`, `showValidationFeedback`, `askDecision`. Same
/// mechanics as the design-system guard (decision 133): the bridge decides
/// severity from the `Failure`, so a screen calling a dialog or a snack bar
/// directly is a screen deciding severity on its own.
void main() {
  /// Calls that belong to the bridge alone.
  final banned = RegExp(r'(?<![A-Za-z0-9_])(showVgr\w*|showDialog|ScaffoldMessenger)\s*[(<.]');

  /// Screens not migrated yet (PS3 of plano-painel-modelo-setes.md moves
  /// each onto the register factory). This list only SHRINKS: a file that
  /// no longer offends must leave it, which the second test enforces.
  const pendingMigration = <String>{
    'lib/app/modules/interfaces/presentation/page/interface_page.dart',
    'lib/app/modules/system-modules/presentation/page/system_module_page.dart',
  };

  Map<String, List<String>> offenders() {
    final found = <String, List<String>>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');
      // The bridge is where these calls legitimately live.
      if (path.contains('/shared/feedback/')) continue;

      final lines = entity.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        final code = lines[index].split('//').first;
        if (banned.hasMatch(code)) {
          found.putIfAbsent(path, () => []).add('$path:${index + 1}');
        }
      }
    }
    return found;
  }

  test('no screen shows a dialog or a snack bar outside the feedback bridge (decision 221)', () {
    final unexpected = offenders().entries
        .where((entry) => !pendingMigration.contains(entry.key))
        .expand((entry) => entry.value)
        .toList();

    expect(
      unexpected,
      isEmpty,
      reason: 'Direct feedback calls found. Decision 221 requires the bridge in '
          'lib/app/shared/feedback/ (showSuccessFeedback / showFailureFeedback / '
          'showValidationFeedback / askDecision):\n${unexpected.join('\n')}',
    );
  });

  test('the pending-migration list holds only files that still offend', () {
    final stillOffending = offenders().keys.toSet();
    final stale = pendingMigration.difference(stillOffending);

    expect(
      stale,
      isEmpty,
      reason: 'These files no longer call feedback directly — remove them from '
          'pendingMigration so the guard covers them:\n${stale.join('\n')}',
    );
  });
}
