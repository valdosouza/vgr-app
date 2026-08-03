import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/auth/data/auth_repository_impl.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient apiClient;
  late AuthRepositoryImpl repository;

  setUp(() {
    apiClient = MockApiClient();
    repository = AuthRepositoryImpl(apiClient);
  });

  test('login reaches the admin-login endpoint, sets the ApiClient token, and returns Right(jwt)', () async {
    when(() => apiClient.post('/auth/admin-login', {'email': 'valdo@vgr.com.br', 'password': 'teste'}))
        .thenAnswer((_) async => {'jwt': 'fake.jwt.token'});
    when(() => apiClient.setToken(any())).thenReturn(null);

    final result = await repository.login('valdo@vgr.com.br', 'teste');

    expect(result, const Right<Failure, String>('fake.jwt.token'));
    verify(() => apiClient.setToken('fake.jwt.token')).called(1);
  });

  test('login converts an ApiClient Failure into Left without setting a token', () async {
    when(() => apiClient.post(any(), any())).thenThrow(
      const Failure(message: 'Invalid email or password', statusCode: 401),
    );

    final result = await repository.login('valdo@vgr.com.br', 'wrong');

    expect(result, const Left<Failure, String>(Failure(message: 'Invalid email or password', statusCode: 401)));
    verifyNever(() => apiClient.setToken(any()));
  });
}
