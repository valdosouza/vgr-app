import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Silent session renewal (decision 112): the panel token lives 15 minutes,
/// so the client swaps it before expiry instead of dropping the user at the
/// login page mid-task.
String jwtExpiringIn(Duration remaining) {
  final exp = DateTime.now().add(remaining).millisecondsSinceEpoch ~/ 1000;
  final payload = base64Url.encode(utf8.encode(jsonEncode({'userId': 1, 'exp': exp})));
  return 'header.$payload.signature';
}

void main() {
  test('renews the token before a call when it is about to expire', () async {
    final requests = <String>[];
    final client = MockClient((request) async {
      requests.add(request.url.path);
      if (request.url.path == '/api/auth/renew') {
        return http.Response(jsonEncode({'jwt': jwtExpiringIn(const Duration(minutes: 15))}), 200);
      }
      return http.Response(jsonEncode({'ok': true, 'data': []}), 200);
    });
    String? renewed;
    final api = ApiClient(
      baseUrl: '',
      httpClient: client,
      onTokenRenewed: (jwt) => renewed = jwt,
    )..setToken(jwtExpiringIn(const Duration(seconds: 30)));

    await api.get('/api/users');

    expect(requests, ['/api/auth/renew', '/api/users']);
    expect(renewed, isNotNull);
    expect(api.token, renewed);
  });

  test('an injected renewToken replaces the panel exchange and may call back in',
      () async {
    final requests = <String>[];
    final client = MockClient((request) async {
      requests.add(request.url.path);
      if (request.url.path == '/app-auth/refresh') {
        return http.Response(
          jsonEncode({
            'ok': true,
            'data': {'accessToken': jwtExpiringIn(const Duration(minutes: 30))}
          }),
          200,
        );
      }
      return http.Response(jsonEncode({'ok': true, 'data': []}), 200);
    });
    late ApiClient api;
    api = ApiClient(
      baseUrl: '',
      httpClient: client,
      // Re-enters the client: must not deadlock on its own pending renewal.
      renewToken: (_) async {
        final json = await api.post('/app-auth/refresh', {'refreshToken': 'r'});
        return (json['data'] as Map)['accessToken'] as String;
      },
    )..setToken(jwtExpiringIn(const Duration(seconds: 30)));

    await api.get('/app-reports/1');

    expect(requests, ['/app-auth/refresh', '/app-reports/1']);
    expect(requests, isNot(contains('/api/auth/renew')));
    expect(shouldRenewJwt(api.token!), isFalse);
  });

  test('a renewToken answering null leaves the token untouched and the call proceeds',
      () async {
    final requests = <String>[];
    final client = MockClient((request) async {
      requests.add(request.url.path);
      return http.Response(jsonEncode({'ok': true, 'data': []}), 200);
    });
    final stale = jwtExpiringIn(const Duration(seconds: 30));
    final api = ApiClient(baseUrl: '', httpClient: client, renewToken: (_) async => null)
      ..setToken(stale);

    await api.get('/app-reports/1');

    expect(requests, ['/app-reports/1']);
    expect(api.token, stale);
  });

  test('does not renew while the token is still comfortably valid', () async {
    final requests = <String>[];
    final client = MockClient((request) async {
      requests.add(request.url.path);
      return http.Response(jsonEncode({'ok': true, 'data': []}), 200);
    });
    final api = ApiClient(baseUrl: '', httpClient: client)
      ..setToken(jwtExpiringIn(const Duration(minutes: 10)));

    await api.get('/api/users');

    expect(requests, ['/api/users']);
  });

  test('concurrent calls share a single renewal', () async {
    var renewals = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/api/auth/renew') {
        renewals++;
        return http.Response(jsonEncode({'jwt': jwtExpiringIn(const Duration(minutes: 15))}), 200);
      }
      return http.Response(jsonEncode({'ok': true, 'data': []}), 200);
    });
    final api = ApiClient(baseUrl: '', httpClient: client)
      ..setToken(jwtExpiringIn(const Duration(seconds: 30)));

    await Future.wait([api.get('/api/a'), api.get('/api/b'), api.get('/api/c')]);

    expect(renewals, 1);
  });

  test('a failed renewal does not break the call — the API answers 401 and the app reacts', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/auth/renew') {
        return http.Response(jsonEncode({'error': 'Invalid or expired token'}), 401);
      }
      return http.Response(jsonEncode({'error': 'Invalid or expired token', 'code': 'UNAUTHORIZED'}), 401);
    });
    final api = ApiClient(baseUrl: '', httpClient: client)
      ..setToken(jwtExpiringIn(const Duration(seconds: 30)));

    await expectLater(
      api.get('/api/users'),
      throwsA(isA<Failure>().having((f) => f.statusCode, 'statusCode', 401)),
    );
  });

  test('never renews when there is no stored token (anonymous calls)', () async {
    final requests = <String>[];
    final client = MockClient((request) async {
      requests.add(request.url.path);
      return http.Response(jsonEncode({'ok': true}), 200);
    });
    final api = ApiClient(baseUrl: '', httpClient: client);

    await api.get('/health');

    expect(requests, ['/health']);
  });
}

/// Minimal stand-in for package:http/testing's MockClient — the core
/// package does not depend on it, and this is all the tests need.
class MockClient extends http.BaseClient {
  MockClient(this._handler);

  final Future<http.Response> Function(http.Request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request as http.Request);
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }
}
