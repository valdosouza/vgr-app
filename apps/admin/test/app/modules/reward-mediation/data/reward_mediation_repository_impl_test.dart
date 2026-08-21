import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/reward-mediation/data/reward_mediation_repository_impl.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient apiClient;
  late RewardMediationRepositoryImpl repository;

  setUp(() {
    apiClient = MockApiClient();
    repository = RewardMediationRepositoryImpl(apiClient);
  });

  test('getState unwraps data and maps offer, resolution, contests and log', () async {
    when(() => apiClient.get('/api/reward-mediation/7')).thenAnswer((_) async => {
          'ok': true,
          'data': {
            'offer': {
              'id': 1,
              'reportId': 7,
              'amountCents': 15000,
              'status': 'reserved',
              'criteriaVersion': 'crit-1',
            },
            'resolution': {
              'id': 11,
              'outcome': 'fulfilled',
              'reason': 'Condition met',
              'criteriaVersion': 'crit-1',
              'proposedBy': 3,
              'approvedBy': 4,
              'windowEndsAt': '2026-08-28T12:00:00.000Z',
              'status': 'approved',
            },
            'openContests': [
              {'id': 21, 'accountId': 8, 'body': 'I disagree'},
            ],
            'log': [
              {'event': 'proposed', 'actorRef': 'user:3', 'details': 'fulfilled'},
            ],
          },
        });

    final result = await repository.getState(7);

    final entity = result.getOrElse(() => throw StateError('left'));
    expect(entity.reportId, 7);
    expect(entity.criteriaVersion, 'crit-1');
    expect(entity.resolution?.status, 'approved');
    expect(entity.openContests.single.accountId, 8);
    expect(entity.log.single.event, 'proposed');
  });

  test('propose posts outcome and reason (decision 148 step 1)', () async {
    when(() => apiClient.post('/api/reward-mediation/7/propose', any()))
        .thenAnswer((_) async => {'resolutionId': 11});

    final result = await repository.propose(7, 'fulfilled', 'Condition met');

    expect(result.isRight(), isTrue);
    final body =
        verify(() => apiClient.post('/api/reward-mediation/7/propose', captureAny()))
            .captured
            .single as Map<String, dynamic>;
    expect(body, {'outcome': 'fulfilled', 'reason': 'Condition met'});
  });

  test('approve, cancel and execute hit their endpoints', () async {
    when(() => apiClient.post(any(), any())).thenAnswer((_) async => {'ok': true});

    expect((await repository.approve(7)).isRight(), isTrue);
    expect((await repository.cancel(7)).isRight(), isTrue);
    expect((await repository.execute(7)).isRight(), isTrue);

    verify(() => apiClient.post('/api/reward-mediation/7/approve', any())).called(1);
    verify(() => apiClient.post('/api/reward-mediation/7/cancel', any())).called(1);
    verify(() => apiClient.post('/api/reward-mediation/7/execute', any())).called(1);
  });

  test('closeContest posts the mandatory note (decision 149)', () async {
    when(() => apiClient.post('/api/reward-mediation/contests/21/close', any()))
        .thenAnswer((_) async => {'ok': true});

    final result = await repository.closeContest(21, 'Reviewed, unfounded');

    expect(result.isRight(), isTrue);
    final body = verify(() =>
            apiClient.post('/api/reward-mediation/contests/21/close', captureAny()))
        .captured
        .single as Map<String, dynamic>;
    expect(body, {'note': 'Reviewed, unfounded'});
  });

  test('publishCriteria posts version and body (decision 150)', () async {
    when(() => apiClient.post('/api/reward-mediation/criteria', any()))
        .thenAnswer((_) async => {'criteriaId': 1});

    final result = await repository.publishCriteria('crit-1', 'The rules.');

    expect(result.isRight(), isTrue);
  });

  test('a Failure surfaces as Left with its code intact', () async {
    when(() => apiClient.post('/api/reward-mediation/7/approve', any()))
        .thenThrow(const Failure(
            message: 'The approver must be a different user than the proposer',
            statusCode: 422,
            code: 'BUSINESS_RULE'));

    final result = await repository.approve(7);

    expect(result.fold((f) => f.code, (_) => null), 'BUSINESS_RULE');
  });
}
