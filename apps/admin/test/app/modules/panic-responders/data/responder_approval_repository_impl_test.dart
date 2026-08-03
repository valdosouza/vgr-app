import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/panic-responders/data/responder_approval_repository_impl.dart';
import 'package:vgr_admin/app/modules/panic-responders/domain/entity/responder_approval_entity.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient apiClient;
  late ResponderApprovalRepositoryImpl repository;

  setUp(() {
    apiClient = MockApiClient();
    repository = ResponderApprovalRepositoryImpl(apiClient);
  });

  test('listPending returns Right(entities) mapped in full from the API response', () async {
    when(() => apiClient.get('/api/panic/responder-pool')).thenAnswer(
      (_) async => {
        'ok': true,
        'data': [
          {'id': 1, 'userId': 42, 'status': 'pending', 'criteriaNotes': 'Volunteer firefighter, 5 years'},
          {'id': 2, 'userId': 43, 'status': 'pending', 'criteriaNotes': null},
        ],
      },
    );

    final result = await repository.listPending();

    result.fold(
      (failure) => fail('expected Right, got Left($failure)'),
      (entities) => expect(entities, [
        const ResponderApprovalEntity(
          id: 1,
          userId: 42,
          status: ResponderApprovalStatus.pending,
          criteriaNotes: 'Volunteer firefighter, 5 years',
        ),
        const ResponderApprovalEntity(
          id: 2,
          userId: 43,
          status: ResponderApprovalStatus.pending,
          criteriaNotes: null,
        ),
      ]),
    );
  });

  test('listPending converts an ApiClient Failure into Left', () async {
    when(() => apiClient.get(any())).thenThrow(
      const Failure(message: 'No connectivity'),
    );

    final result = await repository.listPending();

    expect(result, const Left<Failure, List<ResponderApprovalEntity>>(Failure(message: 'No connectivity')));
  });

  test('resolve(approved: true) reaches the resolve endpoint and returns Right(unit)', () async {
    when(() => apiClient.put('/api/panic/responder-pool/1/resolve', {'approved': true})).thenAnswer(
      (_) async => {'ok': true, 'data': {'id': 1, 'approved': true}},
    );

    final result = await repository.resolve(1, true);

    expect(result, const Right<Failure, Unit>(unit));
    verify(() => apiClient.put('/api/panic/responder-pool/1/resolve', {'approved': true})).called(1);
  });

  test('resolve converts an ApiClient Failure into Left', () async {
    when(() => apiClient.put(any(), any())).thenThrow(
      const Failure(message: 'Forbidden', statusCode: 403),
    );

    final result = await repository.resolve(1, true);

    expect(result, const Left<Failure, Unit>(Failure(message: 'Forbidden', statusCode: 403)));
  });
}
