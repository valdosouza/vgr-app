import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:core/src/error/failure.dart';
import 'package:core/src/network/api_client.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late MockHttpClient httpClient;
  late ApiClient apiClient;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://fallback.test'));
  });

  setUp(() {
    httpClient = MockHttpClient();
    apiClient = ApiClient(baseUrl: 'https://api.test', httpClient: httpClient);
  });

  test('put returns the decoded JSON body on a 2xx response', () async {
    when(() => httpClient.put(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer(
      (_) async => http.Response(
        jsonEncode({
          'ok': true,
          'data': {'category': 'trafficking', 'tier': 'high'},
        }),
        200,
      ),
    );

    final result = await apiClient.put('/api/risk-config/trafficking', {'tier': 'high'});

    expect(result['data'], {'category': 'trafficking', 'tier': 'high'});
  });

  test('put throws a Failure carrying the status code and error message on a non-2xx response', () async {
    when(() => httpClient.put(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer(
      (_) async => http.Response(jsonEncode({'error': 'Forbidden', 'code': 'FORBIDDEN'}), 403),
    );

    await expectLater(
      () => apiClient.put('/api/risk-config/trafficking', {'tier': 'high'}),
      throwsA(
        isA<Failure>()
            .having((f) => f.statusCode, 'statusCode', 403)
            .having((f) => f.message, 'message', 'Forbidden')
            .having((f) => f.code, 'code', 'FORBIDDEN'),
      ),
    );
  });

  test('get returns the decoded JSON body on a 2xx response', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => http.Response(
        jsonEncode({
          'ok': true,
          'data': [
            {'category': 'trafficking', 'tier': 'high'},
          ],
        }),
        200,
      ),
    );

    final result = await apiClient.get('/api/risk-config');

    expect(result['data'], [
      {'category': 'trafficking', 'tier': 'high'},
    ]);
  });

  test('get throws a Failure on a non-2xx response', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => http.Response(jsonEncode({'error': 'No connectivity'}), 500),
    );

    await expectLater(
      () => apiClient.get('/api/risk-config'),
      throwsA(isA<Failure>().having((f) => f.statusCode, 'statusCode', 500)),
    );
  });

  test('post returns the decoded JSON body on a 2xx response', () async {
    when(() => httpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer(
      (_) async => http.Response(
        jsonEncode({
          'ok': true,
          'data': {'id': 1, 'status': 'pending'},
        }),
        201,
      ),
    );

    final result = await apiClient.post('/api/dual-control-access', {'legalBasis': 'x'});

    expect(result['data'], {'id': 1, 'status': 'pending'});
  });

  test('post throws a Failure carrying the status code and error message on a non-2xx response', () async {
    when(() => httpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer(
      (_) async => http.Response(jsonEncode({'error': 'Forbidden', 'code': 'FORBIDDEN'}), 403),
    );

    await expectLater(
      () => apiClient.post('/api/dual-control-access', {'legalBasis': 'x'}),
      throwsA(
        isA<Failure>()
            .having((f) => f.statusCode, 'statusCode', 403)
            .having((f) => f.message, 'message', 'Forbidden')
            .having((f) => f.code, 'code', 'FORBIDDEN'),
      ),
    );
  });

  test('put sends a Bearer Authorization header when a token is provided', () async {
    when(() => httpClient.put(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => http.Response(jsonEncode({'ok': true, 'data': {}}), 200));

    await apiClient.put('/api/risk-config/trafficking', {'tier': 'high'}, token: 'abc');

    final captured = verify(() => httpClient.put(
          any(),
          headers: captureAny(named: 'headers'),
          body: any(named: 'body'),
        )).captured.single as Map<String, String>;
    expect(captured['Authorization'], 'Bearer abc');
  });

  test('setToken makes get/put/post send the Authorization header automatically, with no per-call token needed', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => http.Response(jsonEncode({'ok': true, 'data': []}), 200),
    );

    apiClient.setToken('session-jwt');
    await apiClient.get('/api/risk-config');

    final captured = verify(() => httpClient.get(any(), headers: captureAny(named: 'headers')))
        .captured
        .single as Map<String, String>;
    expect(captured['Authorization'], 'Bearer session-jwt');
  });

  test('an explicit token argument overrides the one set via setToken', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => http.Response(jsonEncode({'ok': true, 'data': []}), 200),
    );

    apiClient.setToken('session-jwt');
    await apiClient.get('/api/risk-config', token: 'override-jwt');

    final captured = verify(() => httpClient.get(any(), headers: captureAny(named: 'headers')))
        .captured
        .single as Map<String, String>;
    expect(captured['Authorization'], 'Bearer override-jwt');
  });
}
