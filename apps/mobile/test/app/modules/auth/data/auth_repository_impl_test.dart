import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_mobile/app/modules/auth/data/auth_repository_impl.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient apiClient;
  late AuthRepositoryImpl repository;

  setUp(() {
    apiClient = MockApiClient();
    repository = AuthRepositoryImpl(apiClient);
  });

  Map<String, dynamic> sessionJson() => {
        'ok': true,
        'data': {'accessToken': 'access-1', 'refreshToken': 'refresh-1', 'accountId': 7},
      };

  group('register', () {
    test('posts to /app-auth/register and sets the token on success', () async {
      when(() => apiClient.post('/app-auth/register', any()))
          .thenAnswer((_) async => sessionJson());

      final result = await repository.register(
        displayName: 'Ana',
        email: 'ana@example.com',
        password: 'uma senha longa o suficiente',
        consentVersion: 'v1',
      );

      final session = result.getOrElse(() => throw StateError('expected Right'));
      expect(session.accessToken, 'access-1');
      expect(session.refreshToken, 'refresh-1');
      expect(session.accountId, 7);
      verify(() => apiClient.setToken('access-1')).called(1);
      final body = verify(() => apiClient.post('/app-auth/register', captureAny()))
          .captured
          .single as Map<String, dynamic>;
      expect(body, {
        'displayName': 'Ana',
        'email': 'ana@example.com',
        'password': 'uma senha longa o suficiente',
        'consentVersion': 'v1',
      });
    });

    test('a duplicate email surfaces as Left(DUPLICATE)', () async {
      when(() => apiClient.post('/app-auth/register', any())).thenThrow(
        const Failure(message: 'dup', statusCode: 409, code: 'DUPLICATE'),
      );

      final result = await repository.register(
        displayName: 'Ana',
        email: 'ana@example.com',
        password: 'uma senha longa o suficiente',
        consentVersion: 'v1',
      );

      expect(result.fold((f) => f.code, (_) => null), 'DUPLICATE');
      verifyNever(() => apiClient.setToken(any()));
    });
  });

  group('login', () {
    test('posts to /app-auth/login and sets the token on success', () async {
      when(() => apiClient.post('/app-auth/login', any()))
          .thenAnswer((_) async => sessionJson());

      final result =
          await repository.login(email: 'ana@example.com', password: 'senha certa');

      expect(result.isRight(), isTrue);
      verify(() => apiClient.setToken('access-1')).called(1);
      final body = verify(() => apiClient.post('/app-auth/login', captureAny()))
          .captured
          .single as Map<String, dynamic>;
      expect(body.containsKey('totpCode'), isFalse);
    });

    test('includes totpCode only when given', () async {
      when(() => apiClient.post('/app-auth/login', any()))
          .thenAnswer((_) async => sessionJson());

      await repository.login(email: 'a@b.com', password: 'x', totpCode: '123456');

      final body = verify(() => apiClient.post('/app-auth/login', captureAny()))
          .captured
          .single as Map<String, dynamic>;
      expect(body['totpCode'], '123456');
    });

    test('wrong credentials surface as Left', () async {
      when(() => apiClient.post('/app-auth/login', any())).thenThrow(
        const Failure(message: 'bad', statusCode: 401, code: 'UNAUTHORIZED'),
      );

      final result = await repository.login(email: 'a@b.com', password: 'wrong');

      expect(result.fold((f) => f.code, (_) => null), 'UNAUTHORIZED');
    });
  });

  group('refresh', () {
    test('posts the refresh token and rotates the session', () async {
      when(() => apiClient.post('/app-auth/refresh', any()))
          .thenAnswer((_) async => sessionJson());

      final result = await repository.refresh('old-refresh');

      expect(result.isRight(), isTrue);
      verify(() => apiClient.post('/app-auth/refresh', {'refreshToken': 'old-refresh'}))
          .called(1);
    });
  });

  group('email verification', () {
    test('sendEmailVerification posts with no body', () async {
      when(() => apiClient.post('/app-auth/verify-email/send', any()))
          .thenAnswer((_) async => {'ok': true});

      final result = await repository.sendEmailVerification();

      expect(result.isRight(), isTrue);
    });

    test('confirmEmailVerification posts the code', () async {
      when(() => apiClient.post('/app-auth/verify-email/confirm', any()))
          .thenAnswer((_) async => {'ok': true});

      final result = await repository.confirmEmailVerification('123456');

      expect(result.isRight(), isTrue);
      verify(() => apiClient.post('/app-auth/verify-email/confirm', {'code': '123456'}))
          .called(1);
    });

    test('a wrong code surfaces as Left', () async {
      when(() => apiClient.post('/app-auth/verify-email/confirm', any())).thenThrow(
        const Failure(message: 'Invalid or expired code', statusCode: 401, code: 'UNAUTHORIZED'),
      );

      final result = await repository.confirmEmailVerification('000000');

      expect(result.fold((f) => f.message, (_) => null), 'Invalid or expired code');
    });
  });

  group('signOutEverywhere', () {
    test('clears the token even on success', () async {
      when(() => apiClient.post('/app-auth/sign-out-everywhere', any()))
          .thenAnswer((_) async => {'ok': true});

      final result = await repository.signOutEverywhere();

      expect(result.isRight(), isTrue);
      verify(() => apiClient.setToken(null)).called(1);
    });

    test('clears the token even when the API call fails — sign-out never '
        'fails closed into a stuck session', () async {
      when(() => apiClient.post('/app-auth/sign-out-everywhere', any()))
          .thenThrow(const Failure(message: 'gone', statusCode: 401, code: 'UNAUTHORIZED'));

      final result = await repository.signOutEverywhere();

      expect(result.isLeft(), isTrue);
      verify(() => apiClient.setToken(null)).called(1);
    });
  });
}
