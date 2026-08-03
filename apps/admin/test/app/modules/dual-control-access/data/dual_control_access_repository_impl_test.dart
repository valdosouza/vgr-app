import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/dual-control-access/data/dual_control_access_repository_impl.dart';
import 'package:vgr_admin/app/modules/dual-control-access/domain/entity/dual_control_access_request_entity.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient apiClient;
  late DualControlAccessRepositoryImpl repository;

  setUp(() {
    apiClient = MockApiClient();
    repository = DualControlAccessRepositoryImpl(apiClient);
  });

  test('create reaches the DualControlAccessRequest endpoint and returns Right(id)', () async {
    when(() => apiClient.post('/api/dual-control-access', {
          'accountabilityLogEntryId': 99,
          'legalBasis': 'Court order #123',
        })).thenAnswer(
      (_) async => {
        'ok': true,
        'data': {'id': 1, 'accountabilityLogEntryId': 99, 'legalBasis': 'Court order #123', 'approverIds': <String>[], 'status': 'pending'},
      },
    );

    final result = await repository.create(99, 'Court order #123');

    expect(result, const Right<Failure, String>('1'));
  });

  test('create converts an ApiClient Failure into Left', () async {
    when(() => apiClient.post(any(), any())).thenThrow(
      const Failure(message: 'Forbidden', statusCode: 403),
    );

    final result = await repository.create(99, 'Court order #123');

    expect(result, const Left<Failure, String>(Failure(message: 'Forbidden', statusCode: 403)));
  });

  test('addApproval reaches the approvals endpoint and returns Right(entity) with updated approverIds', () async {
    when(() => apiClient.post('/api/dual-control-access/1/approvals', {'approverId': 'admin-a'})).thenAnswer(
      (_) async => {
        'ok': true,
        'data': {'id': 1, 'accountabilityLogEntryId': 99, 'legalBasis': 'Court order #123', 'approverIds': ['admin-a'], 'status': 'pending'},
      },
    );

    final result = await repository.addApproval('1', 'admin-a');

    result.fold(
      (failure) => fail('expected Right, got Left($failure)'),
      (entity) => expect(
        entity,
        const DualControlAccessRequestEntity(id: '1', legalBasis: 'Court order #123', approverIds: ['admin-a']),
      ),
    );
  });

  test('addApproval converts an ApiClient Failure into Left', () async {
    when(() => apiClient.post(any(), any())).thenThrow(
      const Failure(message: 'This approver has already approved this request', statusCode: 409, code: 'DUPLICATE'),
    );

    final result = await repository.addApproval('1', 'admin-a');

    expect(
      result,
      const Left<Failure, DualControlAccessRequestEntity>(
        Failure(message: 'This approver has already approved this request', statusCode: 409, code: 'DUPLICATE'),
      ),
    );
  });

  test('findPending returns Right(entities) mapped in full from the API response', () async {
    when(() => apiClient.get('/api/dual-control-access')).thenAnswer(
      (_) async => {
        'ok': true,
        'data': [
          {'id': 1, 'accountabilityLogEntryId': 99, 'legalBasis': 'Court order #123', 'approverIds': ['admin-a'], 'status': 'pending'},
        ],
      },
    );

    final result = await repository.findPending();

    result.fold(
      (failure) => fail('expected Right, got Left($failure)'),
      (entities) => expect(entities, [
        const DualControlAccessRequestEntity(id: '1', legalBasis: 'Court order #123', approverIds: ['admin-a']),
      ]),
    );
  });
}
