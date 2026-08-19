import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/case-freeze/domain/entity/case_freeze_state_entity.dart';
import 'package:vgr_admin/app/modules/case-freeze/domain/repository/case_freeze_repository.dart';
import 'package:vgr_admin/app/modules/case-freeze/presentation/bloc/case_freeze_bloc.dart';
import 'package:vgr_admin/app/modules/case-freeze/presentation/page/case_freeze_page.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../../helpers/pump_localized.dart';
import '../../../../helpers/session_access.dart';

class MockCaseFreezeRepository extends Mock implements CaseFreezeRepository {}

const _open = CaseFreezeStateEntity(reportId: 5, status: 'open', frozen: false);
const _frozen = CaseFreezeStateEntity(
  reportId: 5,
  status: 'open',
  frozen: true,
  frozenReason: 'Writ 123/2026',
  frozenAt: '2026-08-19T10:00:00.000Z',
);
const _frozenPending = CaseFreezeStateEntity(
  reportId: 5,
  status: 'open',
  frozen: true,
  frozenReason: 'Writ 123/2026',
  pendingUnfreeze: PendingUnfreezeEntity(
    reason: 'Investigation closed',
    requestedBy: 7,
    requestedAt: '2026-08-19T11:00:00.000Z',
  ),
);

void main() {
  late MockCaseFreezeRepository repository;

  setUp(() {
    grantAllPrivileges();
    repository = MockCaseFreezeRepository();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await pumpLocalized(
      tester,
      BlocProvider(
        create: (_) => CaseFreezeBloc(repository),
        child: const CaseFreezePage(),
      ),
    );
  }

  Future<void> lookup(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('case-id-field')), '5');
    await tester.tap(find.byKey(const Key('case-lookup-button')));
    await tester.pumpAndSettle();
  }

  testWidgets('freeze flow: mandatory reason, then the server state renders '
      '(decision 141)', (tester) async {
    when(() => repository.getState(5)).thenAnswer((_) async => const Right(_open));
    await pumpPage(tester);
    await lookup(tester);

    expect(find.byKey(const Key('case-not-frozen-badge')), findsOneWidget);

    // Empty reason never leaves the screen (141: reason is mandatory).
    await tester.tap(find.byKey(const Key('freeze-button')));
    await tester.pumpAndSettle();
    expect(find.text('Provide the reason (at least 3 characters).'), findsOneWidget);
    verifyNever(() => repository.freeze(any(), any()));

    when(() => repository.freeze(5, 'Writ 123/2026'))
        .thenAnswer((_) async => const Right(null));
    when(() => repository.getState(5)).thenAnswer((_) async => const Right(_frozen));

    await tester.enterText(
        find.byKey(const Key('freeze-reason-field')), 'Writ 123/2026');
    await tester.tap(find.byKey(const Key('freeze-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('case-frozen-badge')), findsOneWidget);
    expect(find.text('Reason: Writ 123/2026'), findsOneWidget);
  });

  testWidgets('a frozen case without pending request offers step 1: request '
      'unfreeze (141d)', (tester) async {
    when(() => repository.getState(5)).thenAnswer((_) async => const Right(_frozen));
    await pumpPage(tester);
    await lookup(tester);

    expect(find.byKey(const Key('request-unfreeze-button')), findsOneWidget);
    expect(find.byKey(const Key('freeze-button')), findsNothing);
    expect(find.byKey(const Key('approve-unfreeze-button')), findsNothing);

    when(() => repository.requestUnfreeze(5, 'Investigation closed'))
        .thenAnswer((_) async => const Right(null));
    when(() => repository.getState(5))
        .thenAnswer((_) async => const Right(_frozenPending));

    await tester.enterText(
        find.byKey(const Key('unfreeze-reason-field')), 'Investigation closed');
    await tester.tap(find.byKey(const Key('request-unfreeze-button')));
    await tester.pumpAndSettle();

    // Step 2 renders: who asked, and the approve action.
    expect(find.byKey(const Key('pending-unfreeze-tile')), findsOneWidget);
    expect(find.byKey(const Key('approve-unfreeze-button')), findsOneWidget);
  });

  testWidgets('a same-user approval renders the server refusal and keeps the '
      'case (141d)', (tester) async {
    when(() => repository.getState(5))
        .thenAnswer((_) async => const Right(_frozenPending));
    when(() => repository.approveUnfreeze(5)).thenAnswer((_) async => const Left(
        Failure(
            message: 'The approver must be a different user than the requester',
            statusCode: 422,
            code: 'BUSINESS_RULE')));
    await pumpPage(tester);
    await lookup(tester);

    await tester.tap(find.byKey(const Key('approve-unfreeze-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('case-action-error')), findsOneWidget);
    expect(find.byKey(const Key('approve-unfreeze-button')), findsOneWidget);
  });

  testWidgets('without the UPDATE grant every action renders disabled '
      '(decision 72 discipline)', (tester) async {
    SessionAccess.instance.applyPermissions(const {
      'case_freeze': [Privileges.view],
    });
    when(() => repository.getState(5)).thenAnswer((_) async => const Right(_open));
    await pumpPage(tester);
    await lookup(tester);

    final button =
        tester.widget<VgrPrimaryButton>(find.byKey(const Key('freeze-button')));
    expect(button.onPressed, isNull);
  });

  testWidgets('a purged/unknown case renders the lookup error', (tester) async {
    when(() => repository.getState(5)).thenAnswer((_) async => const Left(
        Failure(message: 'gone', statusCode: 404, code: 'NOT_FOUND')));
    await pumpPage(tester);
    await lookup(tester);

    expect(find.byKey(const Key('case-lookup-error')), findsOneWidget);
    expect(find.text('Record not found.'), findsOneWidget);
  });
}
