import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/dual-control-access/data/dual_control_access_repository_impl.dart';
import 'package:vgr_admin/app/modules/dual-control-access/domain/entity/dual_control_request_entity.dart';

class MockApiClient extends Mock implements ApiClient {}

const _pendingJson = {
  'id': 5,
  'accountabilityLogEntryId': 1,
  'legalBasis': 'Court order #7',
  'status': 'pending',
  'requestedBy': 7,
  'requestedByName': 'Ana',
  'approvedBy': null,
  'approvedByName': null,
  'approvedAt': null,
  'createdAt': '2026-10-04T21:38:41.000Z',
};

const _pending = DualControlRequestEntity(
  id: 5,
  accountabilityLogEntryId: 1,
  legalBasis: 'Court order #7',
  status: 'pending',
  requestedBy: 7,
  requestedByName: 'Ana',
  createdAt: '2026-10-04T21:38:41.000Z',
);

/// The panel side of `/api/dual-control-access` after round 18
/// (decisions 223–227).
void main() {
  late MockApiClient apiClient;
  late DualControlAccessRepositoryImpl repository;

  setUp(() {
    apiClient = MockApiClient();
    repository = DualControlAccessRepositoryImpl(apiClient);
  });

  test('list asks for the exact page and maps the envelope, names included', () async {
    when(() => apiClient.get('/api/dual-control-access?page=2&pageSize=20&filter=Court')).thenAnswer(
      (_) async => {
        'ok': true,
        'data': {
          'items': [
            _pendingJson,
            {
              'id': 1,
              'accountabilityLogEntryId': 1,
              'legalBasis': 'Court order #1',
              'status': 'void',
              'requestedBy': null,
              'requestedByName': null,
              'approvedBy': null,
              'approvedByName': null,
              'approvedAt': null,
              'createdAt': '2026-10-04T21:33:46.000Z',
            },
          ],
          'page': 2,
          'pageSize': 20,
          'total': 22,
        },
      },
    );

    final result = await repository.list(const PagedQuery(page: 2, filter: ' Court '));

    final page = result.getOrElse(() => throw StateError('expected Right'));
    expect(page.total, 22);
    expect(page.items.first, _pending);
    expect(page.items.last.status, 'void');
    expect(page.items.last.requestedBy, isNull);
  });

  test('request sends only WHAT is asked and WHY — never who asks (223)', () async {
    when(() => apiClient.post('/api/dual-control-access', {
          'accountabilityLogEntryId': 1,
          'legalBasis': 'Court order #7',
        })).thenAnswer((_) async => {'ok': true, 'data': _pendingJson});

    final result = await repository.request(
      const DualControlRequestDraft(accountabilityLogEntryId: 1, legalBasis: 'Court order #7'),
    );

    expect(result, const Right<Failure, DualControlRequestEntity>(_pending));
  });

  test('approve posts an EMPTY body: the approver is the session (223)', () async {
    when(() => apiClient.post('/api/dual-control-access/5/approvals', <String, dynamic>{})).thenAnswer(
      (_) async => {
        'ok': true,
        'data': {
          ..._pendingJson,
          'status': 'granted',
          'approvedBy': 8,
          'approvedByName': 'Bia',
          'approvedAt': '2026-10-04T21:40:00.000Z',
        },
      },
    );

    final result = await repository.approve(5);

    final granted = result.getOrElse(() => throw StateError('expected Right'));
    expect(granted.status, 'granted');
    expect(granted.approvedByName, 'Bia');
  });

  test('a refusal from the API comes back as Left', () async {
    const selfApproval = Failure(
      message: 'The approver must be a different user than the requester',
      statusCode: 422,
      code: 'BUSINESS_RULE',
    );
    when(() => apiClient.post(any(), any())).thenThrow(selfApproval);

    expect(await repository.approve(5), const Left<Failure, DualControlRequestEntity>(selfApproval));
  });
}
