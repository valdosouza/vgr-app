import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/legal-policy/data/legal_policy_repository_impl.dart';
import 'package:vgr_admin/app/modules/legal-policy/domain/entity/legal_policy_entities.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient apiClient;
  late LegalPolicyRepositoryImpl repository;

  setUp(() {
    apiClient = MockApiClient();
    repository = LegalPolicyRepositoryImpl(apiClient);
  });

  Map<String, dynamic> paged(List<Map<String, dynamic>> items) => {
        'ok': true,
        'data': {'items': items, 'page': 1, 'pageSize': 20, 'total': items.length},
      };

  test('lists a page of jurisdictions with pending state (decisions 107/220)', () async {
    when(() => apiClient.get('/api/legal-policy/jurisdictions?page=1&pageSize=20&filter=br'))
        .thenAnswer((_) async => paged([
              {
                'code': 'BR',
                'name': 'Brazil',
                'operationalState': 'suspended',
                'isSandbox': false,
                'pendingState': 'live',
                'pendingBy': 7,
              },
            ]));

    final result = await repository.listJurisdictions(const PagedQuery(filter: 'br'));

    final rows = result.getOrElse(() => throw StateError('left')).items;
    expect(rows.single.pendingState, 'live');
    expect(rows.single.pendingBy, 7);
  });

  test('requestState PUTs the target state', () async {
    when(() => apiClient.put('/api/legal-policy/jurisdictions/BR/state', any()))
        .thenAnswer((_) async => {
              'ok': true,
              'data': {
                'code': 'BR',
                'name': 'Brazil',
                'operationalState': 'suspended',
                'isSandbox': false,
                'pendingState': null,
                'pendingBy': null,
              },
            });

    final result = await repository.requestState('BR', 'suspended');

    expect(result.getOrElse(() => throw StateError('left')).operationalState,
        'suspended');
    final body = verify(() =>
            apiClient.put('/api/legal-policy/jurisdictions/BR/state', captureAny()))
        .captured
        .single as Map<String, dynamic>;
    expect(body, {'state': 'suspended'});
  });

  test('capabilities are read PER jurisdiction, one page at a time (decisions 103/220)', () async {
    when(() => apiClient.get('/api/legal-policy/capabilities?jurisdiction=BR&page=2&pageSize=20'))
        .thenAnswer((_) async => paged([
              {
                'capability': 'report.anonymous',
                'description': 'Anonymous reporting',
                'module': 'reports',
                'effectiveStatus': 'unreviewed',
                'activeRule': null,
              },
            ]));

    final result = await repository.listCapabilities('BR', const PagedQuery(page: 2));

    expect(result.getOrElse(() => throw StateError('left')).items.single.effectiveStatus, 'unreviewed');
  });

  test('rules are listed by page with the text filter', () async {
    when(() => apiClient.get('/api/legal-policy/rules?page=1&pageSize=20&filter=reward'))
        .thenAnswer((_) async => paged([_ruleJson(ruleState: 'active')]));

    final result = await repository.listRules(const PagedQuery(filter: 'reward'));

    expect(result.getOrElse(() => throw StateError('left')).items.single.id, 9);
  });

  test('proposeRule posts the body with reason only when not allowed '
      '(decision 78)', () async {
    when(() => apiClient.post('/api/legal-policy/rules', any()))
        .thenAnswer((_) async => {
              'ok': true,
              'data': _ruleJson(ruleState: 'proposed'),
            });

    const proposal = LegalRuleProposal(
      capability: 'reward.monetary',
      jurisdictionCode: 'BR',
      status: 'blocked',
      reason: 'no_control',
      legalBasis: 'No PSP adapter yet',
    );
    final result = await repository.proposeRule(proposal);

    expect(result.getOrElse(() => throw StateError('left')).ruleState, 'proposed');
    final body = verify(() => apiClient.post('/api/legal-policy/rules', captureAny()))
        .captured
        .single as Map<String, dynamic>;
    expect(body['reason'], 'no_control');
    expect(body['expiresInDays'], 180);
  });

  test('approve failure (same user, 107) surfaces as Left', () async {
    when(() => apiClient.post('/api/legal-policy/rules/9/approve', any()))
        .thenThrow(const Failure(
            message: 'The approver must be a different user',
            statusCode: 422,
            code: 'BUSINESS_RULE'));

    final result = await repository.approveRule(9);

    expect(result.fold((f) => f.code, (_) => null), 'BUSINESS_RULE');
  });
}

Map<String, dynamic> _ruleJson({required String ruleState}) => {
      'id': 9,
      'capability': 'reward.monetary',
      'jurisdictionCode': 'BR',
      'version': 1,
      'status': 'blocked',
      'reason': 'no_control',
      'legalBasis': 'No PSP adapter yet',
      'reviewState': 'none',
      'ruleState': ruleState,
      'effectiveFrom': null,
      'expiresAt': '2027-02-15T00:00:00.000Z',
      'proposedBy': 7,
      'approvedBy': null,
    };
