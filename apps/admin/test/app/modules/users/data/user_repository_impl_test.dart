import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/users/data/user_repository_impl.dart';
import 'package:vgr_admin/app/modules/users/domain/entity/user_entity.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient apiClient;
  late UserRepositoryImpl repository;

  const ana = UserEntity(id: 2, name: 'Ana', email: 'ana@vgr.com.br', locale: 'pt-BR');

  setUp(() {
    apiClient = MockApiClient();
    repository = UserRepositoryImpl(apiClient);
  });

  Map<String, dynamic> echo(Map<String, dynamic> body) => {
        'ok': true,
        'data': {'id': 2, ...body},
      };

  test('list asks for a page filtered on name / email (PS0, decision 220)', () async {
    when(() => apiClient.get('/api/users?page=1&pageSize=20&filter=ana')).thenAnswer(
      (_) async => {
        'ok': true,
        'data': {
          'items': [
            {'id': 2, 'name': 'Ana', 'email': 'ana@vgr.com.br', 'active': 'S'},
          ],
          'page': 1,
          'pageSize': 20,
          'total': 1,
        },
      },
    );

    final result = await repository.list(const PagedQuery(filter: 'ana'));

    result.fold(
      (failure) => fail('expected Right, got Left($failure)'),
      (page) => expect(page.items.single.email, 'ana@vgr.com.br'),
    );
  });

  test('create sends the initial password (decision 75)', () async {
    const body = {'name': 'Ana', 'email': 'ana@vgr.com.br', 'active': 'S', 'password': 'a long password'};
    when(() => apiClient.post('/api/users', body)).thenAnswer((_) async => echo(body));

    await repository.create(const UserDraft(
      name: 'Ana',
      email: 'ana@vgr.com.br',
      active: 'S',
      password: 'a long password',
    ));

    verify(() => apiClient.post('/api/users', body)).called(1);
  });

  test('update echoes the saved locale (the API would null it) and omits an empty password', () async {
    const body = {'name': 'Ana Maria', 'email': 'ana@vgr.com.br', 'active': 'N', 'locale': 'pt-BR'};
    when(() => apiClient.put('/api/users/2', body)).thenAnswer((_) async => echo(body));

    await repository.update(ana, const UserDraft(name: 'Ana Maria', email: 'ana@vgr.com.br', active: 'N'));

    verify(() => apiClient.put('/api/users/2', body)).called(1);
  });

  test('update sends a new password when one was typed', () async {
    const body = {
      'name': 'Ana',
      'email': 'ana@vgr.com.br',
      'active': 'S',
      'locale': 'pt-BR',
      'password': 'another long one',
    };
    when(() => apiClient.put('/api/users/2', body)).thenAnswer((_) async => echo(body));

    await repository.update(
      ana,
      const UserDraft(name: 'Ana', email: 'ana@vgr.com.br', active: 'S', password: 'another long one'),
    );

    verify(() => apiClient.put('/api/users/2', body)).called(1);
  });
}
