import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/reward-mediation/domain/entity/reward_mediation_state_entity.dart';
import 'package:vgr_admin/app/modules/reward-mediation/domain/repository/reward_mediation_repository.dart';
import 'package:vgr_admin/app/modules/reward-mediation/presentation/bloc/reward_mediation_bloc.dart';
import 'package:vgr_admin/app/modules/reward-mediation/presentation/bloc/reward_mediation_event.dart';
import 'package:vgr_admin/app/modules/reward-mediation/presentation/bloc/reward_mediation_state.dart';

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

void main() {
  late MockRewardMediationRepository repository;

  setUp(() => repository = MockRewardMediationRepository());

  RewardMediationBloc build() => RewardMediationBloc(repository);

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('lookup loads the server state', () async {
    when(() => repository.getState(7)).thenAnswer((_) async => const Right(_reserved));

    final bloc = build()..add(const MediationLookupRequested(7));
    await settle();

    expect(bloc.state, const MediationLoaded(_reserved));
  });

  test('propose re-fetches: the screen renders what the SERVER says', () async {
    when(() => repository.getState(7)).thenAnswer((_) async => const Right(_reserved));
    final bloc = build()..add(const MediationLookupRequested(7));
    await settle();

    when(() => repository.propose(7, 'fulfilled', 'Condition met'))
        .thenAnswer((_) async => const Right(null));
    when(() => repository.getState(7)).thenAnswer((_) async => const Right(_proposed));

    bloc.add(const ResolutionProposed('fulfilled', 'Condition met'));
    await settle();

    expect(bloc.state, const MediationLoaded(_proposed));
    verify(() => repository.propose(7, 'fulfilled', 'Condition met')).called(1);
  });

  test('a rejected action keeps the case on screen with the failure '
      '(e.g. same-user approval, decision 148)', () async {
    when(() => repository.getState(7)).thenAnswer((_) async => const Right(_proposed));
    final bloc = build()..add(const MediationLookupRequested(7));
    await settle();

    const failure = Failure(
        message: 'The approver must be a different user than the proposer',
        statusCode: 422,
        code: 'BUSINESS_RULE');
    when(() => repository.approve(7)).thenAnswer((_) async => const Left(failure));

    bloc.add(const ResolutionApproved());
    await settle();

    expect(bloc.state, const MediationLoaded(_proposed, failure: failure));
  });

  test('criteria publish works with no case on screen (decision 150)', () async {
    when(() => repository.publishCriteria('crit-1', 'The rules.'))
        .thenAnswer((_) async => const Right(null));

    final bloc = build()..add(const CriteriaPublishSubmitted('crit-1', 'The rules.'));
    await settle();

    expect(bloc.state, const MediationInitial(criteriaPublished: true));
  });

  test('a duplicate criteria version surfaces its failure', () async {
    const failure = Failure(
        message: 'This criteria version is already published',
        statusCode: 409,
        code: 'DUPLICATE');
    when(() => repository.publishCriteria('crit-1', 'The rules.'))
        .thenAnswer((_) async => const Left(failure));

    final bloc = build()..add(const CriteriaPublishSubmitted('crit-1', 'The rules.'));
    await settle();

    expect(bloc.state, const MediationInitial(criteriaFailure: failure));
  });

  test('mutations without a loaded case are a no-op', () async {
    final bloc = build()..add(const ResolutionExecuted());
    await settle();

    expect(bloc.state, const MediationInitial());
    verifyNever(() => repository.execute(any()));
  });
}
