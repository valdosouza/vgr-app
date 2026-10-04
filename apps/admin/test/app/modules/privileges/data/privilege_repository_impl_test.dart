import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/privileges/data/privilege_repository_impl.dart';
import 'package:vgr_admin/app/modules/privileges/domain/entity/privilege_entity.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient apiClient;
  late PrivilegeRepositoryImpl repository;

  setUp(() {
    apiClient = MockApiClient();
    repository = PrivilegeRepositoryImpl(apiClient);
  });

  test('list asks for a page (PS0, decision 220) and maps the envelope', () async {
    when(() => apiClient.get('/api/privileges?page=2&pageSize=10&filter=VI')).thenAnswer(
      (_) async => {
        'ok': true,
        'data': {
          'items': [
            {'id': 1, 'description': 'VIEW'},
          ],
          'page': 2,
          'pageSize': 10,
          'total': 11,
        },
      },
    );

    final result = await repository.list(const PagedQuery(page: 2, pageSize: 10, filter: 'VI'));

    result.fold(
      (failure) => fail('expected Right, got Left($failure)'),
      (page) => expect(
        page,
        const PagedResult(
          items: [PrivilegeEntity(id: 1, description: 'VIEW')],
          page: 2,
          pageSize: 10,
          total: 11,
        ),
      ),
    );
  });

  test('update targets the row it was opened on, with the draft as body', () async {
    when(() => apiClient.put('/api/privileges/5', {'description': 'EXPORT'})).thenAnswer(
      (_) async => {
        'ok': true,
        'data': {'id': 5, 'description': 'EXPORT'},
      },
    );

    final result = await repository.update(
      const PrivilegeEntity(id: 5, description: 'PRINT'),
      const PrivilegeDraft('EXPORT'),
    );

    expect(result, const Right<Failure, PrivilegeEntity>(PrivilegeEntity(id: 5, description: 'EXPORT')));
  });

  test('a Failure from the client becomes Left', () async {
    when(() => apiClient.delete(any())).thenThrow(
      const Failure(message: 'in use', statusCode: 409, code: 'IN_USE'),
    );

    final result = await repository.delete(const PrivilegeEntity(id: 5, description: 'PRINT'));

    expect(result, const Left<Failure, Unit>(Failure(message: 'in use', statusCode: 409, code: 'IN_USE')));
  });
}
