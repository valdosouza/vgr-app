import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/auth/data/auth_repository_impl.dart';
import 'package:vgr_admin/app/modules/auth/domain/login_result.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient apiClient;
  late AuthRepositoryImpl repository;

  setUp(() {
    apiClient = MockApiClient();
    repository = AuthRepositoryImpl(apiClient);
  });

  test('login reaches the admin-login endpoint, sets the ApiClient token, and returns a session', () async {
    when(() => apiClient.post('/auth/admin-login', {'email': 'valdo@vgr.com.br', 'password': 'teste'}))
        .thenAnswer((_) async => {'jwt': 'fake.jwt.token'});
    when(() => apiClient.setToken(any())).thenReturn(null);

    final result = await repository.login('valdo@vgr.com.br', 'teste');

    expect(result, const Right<Failure, LoginResult>(LoginSession('fake.jwt.token')));
    verify(() => apiClient.setToken('fake.jwt.token')).called(1);
  });

  test('login converts an ApiClient Failure into Left without setting a token', () async {
    when(() => apiClient.post(any(), any())).thenThrow(
      const Failure(message: 'Invalid email or password', statusCode: 401),
    );

    final result = await repository.login('valdo@vgr.com.br', 'wrong');

    expect(result, const Left<Failure, LoginResult>(Failure(message: 'Invalid email or password', statusCode: 401)));
    verifyNever(() => apiClient.setToken(any()));
  });

  test('login sends totpCode when the second factor is supplied (decision 114)', () async {
    when(() => apiClient.post('/auth/admin-login', {
          'email': 'valdo@vgr.com.br',
          'password': 'teste',
          'totpCode': '123456',
        })).thenAnswer((_) async => {'jwt': 'fake.jwt.token'});
    when(() => apiClient.setToken(any())).thenReturn(null);

    final result = await repository.login('valdo@vgr.com.br', 'teste', totpCode: '123456');

    expect(result, const Right<Failure, LoginResult>(LoginSession('fake.jwt.token')));
  });

  test('login returns the enrollment branch and sets NO token (mandatory 2FA, decision 114)', () async {
    when(() => apiClient.post('/auth/admin-login', {'email': 'valdo@vgr.com.br', 'password': 'teste'}))
        .thenAnswer((_) async => {'twoFactorSetupRequired': true, 'enrollToken': 'enroll.token'});

    final result = await repository.login('valdo@vgr.com.br', 'teste');

    expect(result, const Right<Failure, LoginResult>(LoginEnrollmentRequired('enroll.token')));
    verifyNever(() => apiClient.setToken(any()));
  });

  test('activateTwoFactor stores the session token and returns the one-time recovery codes', () async {
    when(() => apiClient.post('/auth/2fa/activate', {'enrollToken': 'enroll.token', 'code': '123456'}))
        .thenAnswer((_) async => {
              'data': {
                'jwt': 'fake.jwt.token',
                'recoveryCodes': ['AAAA1111', 'BBBB2222'],
              }
            });
    when(() => apiClient.setToken(any())).thenReturn(null);

    final result = await repository.activateTwoFactor('enroll.token', '123456');

    expect(result.isRight(), isTrue);
    result.fold((_) {}, (activation) {
      expect(activation.jwt, 'fake.jwt.token');
      expect(activation.recoveryCodes, ['AAAA1111', 'BBBB2222']);
    });
    verify(() => apiClient.setToken('fake.jwt.token')).called(1);
  });
}
