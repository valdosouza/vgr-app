import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/case-freeze/data/case_freeze_repository_impl.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient apiClient;
  late CaseFreezeRepositoryImpl repository;

  setUp(() {
    apiClient = MockApiClient();
    repository = CaseFreezeRepositoryImpl(apiClient);
  });

  test('getState maps the flat server payload, pending unfreeze included', () async {
    when(() => apiClient.get('/api/case-freeze/5')).thenAnswer((_) async => {
          'reportId': 5,
          'status': 'open',
          'frozen': true,
          'frozenReason': 'Writ 123/2026',
          'frozenAt': '2026-08-19T10:00:00.000Z',
          'pendingUnfreeze': {
            'reason': 'Investigation closed',
            'requestedBy': 7,
            'requestedAt': '2026-08-19T11:00:00.000Z',
          },
        });

    final result = await repository.getState(5);

    final entity = result.getOrElse(() => throw StateError('left'));
    expect(entity.frozen, isTrue);
    expect(entity.frozenReason, 'Writ 123/2026');
    expect(entity.pendingUnfreeze?.requestedBy, 7);
  });

  test('freeze posts the mandatory reason (decision 141)', () async {
    when(() => apiClient.post('/api/case-freeze/5/freeze', any()))
        .thenAnswer((_) async => {'reportId': 5, 'frozen': true});

    final result = await repository.freeze(5, 'Writ 123/2026');

    expect(result.isRight(), isTrue);
    final body = verify(() => apiClient.post('/api/case-freeze/5/freeze', captureAny()))
        .captured
        .single as Map<String, dynamic>;
    expect(body, {'reason': 'Writ 123/2026'});
  });

  test('request and approve hit the two dual-control endpoints (141d)', () async {
    when(() => apiClient.post('/api/case-freeze/5/unfreeze-request', any()))
        .thenAnswer((_) async => {'requestId': 1});
    when(() => apiClient.post('/api/case-freeze/5/unfreeze-approve', any()))
        .thenAnswer((_) async => {'reportId': 5, 'frozen': false});

    expect((await repository.requestUnfreeze(5, 'Closed')).isRight(), isTrue);
    expect((await repository.approveUnfreeze(5)).isRight(), isTrue);
  });

  test('a Failure surfaces as Left with its code intact', () async {
    when(() => apiClient.post('/api/case-freeze/5/unfreeze-approve', any()))
        .thenThrow(const Failure(
            message: 'The approver must be a different user than the requester',
            statusCode: 422,
            code: 'BUSINESS_RULE'));

    final result = await repository.approveUnfreeze(5);

    expect(result.fold((f) => f.code, (_) => null), 'BUSINESS_RULE');
  });
}
