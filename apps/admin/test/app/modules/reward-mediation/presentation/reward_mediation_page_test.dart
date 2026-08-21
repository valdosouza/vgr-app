import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/reward-mediation/domain/entity/reward_mediation_state_entity.dart';
import 'package:vgr_admin/app/modules/reward-mediation/domain/repository/reward_mediation_repository.dart';
import 'package:vgr_admin/app/modules/reward-mediation/presentation/bloc/reward_mediation_bloc.dart';
import 'package:vgr_admin/app/modules/reward-mediation/presentation/page/reward_mediation_page.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../../helpers/pump_localized.dart';
import '../../../../helpers/session_access.dart';

class MockRewardMediationRepository extends Mock
    implements RewardMediationRepository {}

const _reserved = RewardMediationStateEntity(
  reportId: 7,
  amountCents: 15000,
  offerStatus: 'reserved',
  criteriaVersion: 'crit-1',
);
const _proposed = RewardMediationStateEntity(
  reportId: 7,
  amountCents: 15000,
  offerStatus: 'reserved',
  criteriaVersion: 'crit-1',
  resolution: RewardResolutionEntity(
    id: 11,
    outcome: 'fulfilled',
    reason: 'Condition met',
    criteriaVersion: 'crit-1',
    proposedBy: 3,
    status: 'proposed',
  ),
);
const _approvedContested = RewardMediationStateEntity(
  reportId: 7,
  amountCents: 15000,
  offerStatus: 'reserved',
  criteriaVersion: 'crit-1',
  resolution: RewardResolutionEntity(
    id: 11,
    outcome: 'fulfilled',
    reason: 'Condition met',
    criteriaVersion: 'crit-1',
    proposedBy: 3,
    approvedBy: 4,
    windowEndsAt: '2026-08-28T12:00:00.000Z',
    status: 'approved',
  ),
  openContests: [RewardContestEntity(id: 21, accountId: 8, body: 'I disagree')],
  log: [MediationLogEntryEntity(event: 'proposed', actorRef: 'user:3')],
);

void main() {
  late MockRewardMediationRepository repository;

  setUp(() {
    grantAllPrivileges();
    repository = MockRewardMediationRepository();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await pumpLocalized(
      tester,
      BlocProvider(
        create: (_) => RewardMediationBloc(repository),
        child: const RewardMediationPage(),
      ),
    );
  }

  Future<void> lookup(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('mediation-case-id-field')), '7');
    await tester.tap(find.byKey(const Key('mediation-lookup-button')));
    await tester.pumpAndSettle();
  }

  testWidgets('propose flow: mandatory reasoning, then the server state renders '
      '(decision 148 step 1)', (tester) async {
    when(() => repository.getState(7)).thenAnswer((_) async => const Right(_reserved));
    await pumpPage(tester);
    await lookup(tester);

    expect(find.byKey(const Key('propose-button')), findsOneWidget);

    // Empty reasoning never leaves the screen.
    await tester.tap(find.byKey(const Key('propose-button')));
    await tester.pumpAndSettle();
    expect(find.text('Provide the reasoning.'), findsOneWidget);
    verifyNever(() => repository.propose(any(), any(), any()));

    when(() => repository.propose(7, 'fulfilled', 'Condition met'))
        .thenAnswer((_) async => const Right(null));
    when(() => repository.getState(7)).thenAnswer((_) async => const Right(_proposed));

    await tester.enterText(
        find.byKey(const Key('propose-reason-field')), 'Condition met');
    await tester.tap(find.byKey(const Key('propose-button')));
    await tester.pumpAndSettle();

    // Step 2 renders: who proposed, and the approve action.
    expect(find.byKey(const Key('proposed-tile')), findsOneWidget);
    expect(find.byKey(const Key('approve-button')), findsOneWidget);
  });

  testWidgets('a same-user approval renders the server refusal and keeps the '
      'case (decision 148)', (tester) async {
    when(() => repository.getState(7)).thenAnswer((_) async => const Right(_proposed));
    when(() => repository.approve(7)).thenAnswer((_) async => const Left(Failure(
        message: 'The approver must be a different user than the proposer',
        statusCode: 422,
        code: 'BUSINESS_RULE')));
    await pumpPage(tester);
    await lookup(tester);

    await tester.tap(find.byKey(const Key('approve-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mediation-action-error')), findsOneWidget);
    expect(find.byKey(const Key('approve-button')), findsOneWidget);
  });

  testWidgets('an approved resolution with an open contest shows the contest, '
      'its close action and the execute action (decision 149)', (tester) async {
    when(() => repository.getState(7))
        .thenAnswer((_) async => const Right(_approvedContested));
    await pumpPage(tester);
    await lookup(tester);

    expect(find.byKey(const Key('contest-tile-21')), findsOneWidget);
    expect(find.byKey(const Key('execute-button')), findsOneWidget);

    when(() => repository.closeContest(21, 'Reviewed, unfounded'))
        .thenAnswer((_) async => const Right(null));

    // The contest block sits below the fold in the test viewport.
    await tester.ensureVisible(find.byKey(const Key('contest-note-field')));
    await tester.enterText(
        find.byKey(const Key('contest-note-field')), 'Reviewed, unfounded');
    await tester.ensureVisible(find.byKey(const Key('close-contest-button')));
    await tester.tap(find.byKey(const Key('close-contest-button')));
    await tester.pumpAndSettle();

    verify(() => repository.closeContest(21, 'Reviewed, unfounded')).called(1);
  });

  testWidgets('without the UPDATE grant every action renders disabled '
      '(decision 72 discipline)', (tester) async {
    SessionAccess.instance.applyPermissions(const {
      'reward_mediation': [Privileges.view],
    });
    when(() => repository.getState(7)).thenAnswer((_) async => const Right(_reserved));
    await pumpPage(tester);
    await lookup(tester);

    final button =
        tester.widget<VgrPrimaryButton>(find.byKey(const Key('propose-button')));
    expect(button.onPressed, isNull);
  });

  testWidgets('a case without a reward renders the lookup error', (tester) async {
    when(() => repository.getState(7)).thenAnswer((_) async => const Left(
        Failure(message: 'gone', statusCode: 404, code: 'NOT_FOUND')));
    await pumpPage(tester);
    await lookup(tester);

    expect(find.byKey(const Key('mediation-lookup-error')), findsOneWidget);
  });

  testWidgets('with no case on screen the criteria section publishes a version '
      '(decision 150)', (tester) async {
    when(() => repository.publishCriteria('crit-1', 'The rules.'))
        .thenAnswer((_) async => const Right(null));
    await pumpPage(tester);

    await tester.enterText(
        find.byKey(const Key('criteria-version-field')), 'crit-1');
    await tester.enterText(
        find.byKey(const Key('criteria-body-field')), 'The rules.');
    await tester.tap(find.byKey(const Key('criteria-publish-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('criteria-published')), findsOneWidget);
  });
}
