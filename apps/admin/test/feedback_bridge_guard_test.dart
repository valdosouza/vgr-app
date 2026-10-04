import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guard for decision 221: **screens talk back to the user only through
/// the feedback bridge** (`lib/app/shared/feedback/`) — `showSuccessFeedback`,
/// `showFailureFeedback`, `showValidationFeedback`, `askDecision`. Same
/// mechanics as the design-system guard (decision 133): the bridge decides
/// severity from the `Failure`, so a screen calling a dialog or a snack bar
/// directly is a screen deciding severity on its own.
///
/// PS2 introduced it with a list of screens pending migration; PS3 emptied
/// that list, so the rule now holds with no exception.
void main() {
  /// Calls that belong to the bridge alone.
  final banned = RegExp(r'(?<![A-Za-z0-9_])(showVgr\w*|showDialog|ScaffoldMessenger)\s*[(<.]');

  test('no screen shows a dialog or a snack bar outside the feedback bridge (decision 221)', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');
      // The bridge is where these calls legitimately live.
      if (path.contains('/shared/feedback/')) continue;

      final lines = entity.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        final code = lines[index].split('//').first;
        if (banned.hasMatch(code)) offenders.add('$path:${index + 1}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Direct feedback calls found. Decision 221 requires the bridge in '
          'lib/app/shared/feedback/ (showSuccessFeedback / showFailureFeedback / '
          'showValidationFeedback / askDecision):\n${offenders.join('\n')}',
    );
  });
}
