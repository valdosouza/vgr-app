import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vgr_admin/app/shared/feedback/feedback.dart';

import '../../../helpers/pump_localized.dart';

/// The feedback bridge (decision 221): severity comes from the Failure,
/// never from the screen.
void main() {
  Future<BuildContext> pumpHost(WidgetTester tester) async {
    late BuildContext captured;
    await pumpLocalized(
      tester,
      Scaffold(
        body: Builder(builder: (context) {
          captured = context;
          return const SizedBox.shrink();
        }),
      ),
    );
    return captured;
  }

  testWidgets('a 4xx failure is a transient message, translated by code', (tester) async {
    final context = await pumpHost(tester);

    showFailureFeedback(
      context,
      const Failure(message: 'in use', statusCode: 409, code: 'IN_USE'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('This record is in use and cannot be deleted.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a 5xx or an unanswered request is a dialog to acknowledge', (tester) async {
    final context = await pumpHost(tester);

    showFailureFeedback(context, const Failure(message: 'Internal error', statusCode: 500, code: 'INTERNAL'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Something went wrong'), findsOneWidget);
    await tester.tap(find.byKey(feedbackCloseKey));
    await tester.pumpAndSettle();

    showFailureFeedback(context, const Failure(message: 'offline'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('success is a transient message', (tester) async {
    final context = await pumpHost(tester);

    showSuccessFeedback(context, 'Record saved.');
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Record saved.'), findsOneWidget);
  });

  testWidgets('a validation pendency is a dialog that completes when closed', (tester) async {
    final context = await pumpHost(tester);
    var closed = false;

    showValidationFeedback(context, 'Name: Required field.').then((_) => closed = true);
    await tester.pumpAndSettle();
    expect(find.text('Check this field'), findsOneWidget);
    expect(find.text('Name: Required field.'), findsOneWidget);

    await tester.tap(find.byKey(feedbackCloseKey));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
  });

  testWidgets('askDecision answers yes / no, and dismissal is the cautious answer', (tester) async {
    final context = await pumpHost(tester);
    final answers = <Decision>[];

    askDecision(context, title: 'Delete?', message: 'Sure?').then(answers.add);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(decisionYesKey));
    await tester.pumpAndSettle();

    askDecision(context, title: 'Delete?', message: 'Sure?').then(answers.add);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    askDecision(context, title: 'Leave?', message: 'Unsaved', withCancel: true).then(answers.add);
    await tester.pumpAndSettle();
    expect(find.byKey(decisionCancelKey), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(answers, [Decision.yes, Decision.no, Decision.cancel]);
  });

  test('technical = no status or 5xx', () {
    expect(isTechnicalFailure(const Failure(message: 'x')), isTrue);
    expect(isTechnicalFailure(const Failure(message: 'x', statusCode: 503)), isTrue);
    expect(isTechnicalFailure(const Failure(message: 'x', statusCode: 422)), isFalse);
  });
}
