import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  group('CurrentUser', () {
    test('parses /api/core/me and uses the name as the badge label', () {
      final user = CurrentUser.fromJson({'id': 2, 'name': 'Webmaster', 'email': 'w@x.com', 'locale': 'pt-BR'});
      expect(user.displayName, 'Webmaster');
      expect(user.locale, 'pt-BR');
    });

    test('falls back to the e-mail while the name is blank (seed bootstrap account)', () {
      final user = CurrentUser.fromJson({'id': 1, 'name': '', 'email': 'valdo@vgr.com.br', 'locale': null});
      expect(user.displayName, 'valdo@vgr.com.br');
    });
  });

  group('CurrentUserRepositoryImpl', () {
    late MockApiClient apiClient;

    setUp(() => apiClient = MockApiClient());

    test('reads the data envelope', () async {
      when(() => apiClient.get('/api/core/me', token: any(named: 'token'), headers: any(named: 'headers')))
          .thenAnswer((_) async => {'ok': true, 'data': {'id': 2, 'name': 'W', 'email': 'w@x.com', 'locale': null}});

      final result = await CurrentUserRepositoryImpl(apiClient).getMe();

      expect(result.getOrElse(() => throw StateError('left')).email, 'w@x.com');
    });

    test('a Failure surfaces as Left', () async {
      when(() => apiClient.get('/api/core/me', token: any(named: 'token'), headers: any(named: 'headers')))
          .thenThrow(const Failure(message: 'expired', statusCode: 401));

      final result = await CurrentUserRepositoryImpl(apiClient).getMe();

      expect(result.fold((f) => f.statusCode, (_) => null), 401);
    });
  });
}
