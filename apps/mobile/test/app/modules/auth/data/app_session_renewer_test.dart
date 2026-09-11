import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vgr_mobile/app/modules/auth/data/app_session_renewer.dart';

/// App-plane silent renewal (decisions 119/122): the shared client's
/// default exchange is the panel's `/api/auth/renew`, which rejects app
/// tokens; the app renews with its refresh token at `/app-auth/refresh`.
String _jwtExpiringIn(Duration remaining) {
  final exp = DateTime.now().add(remaining).millisecondsSinceEpoch ~/ 1000;
  final payload = base64Url.encode(utf8.encode(jsonEncode({'accountId': 1, 'exp': exp})));
  return 'h.$payload.s';
}

void main() {
  late List<http.Request> requests;
  late IdentityBloc identity;

  ApiClient client({required bool refreshOk}) {
    requests = [];
    late ApiClient api;
    api = ApiClient(
      baseUrl: '',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/app-auth/refresh') {
          if (!refreshOk) {
            return http.Response(jsonEncode({'error': 'x', 'code': 'UNAUTHORIZED'}), 401);
          }
          return http.Response(
            jsonEncode({
              'ok': true,
              'data': {
                'accessToken': _jwtExpiringIn(const Duration(minutes: 30)),
                'refreshToken': 'rotated',
                'accountId': 1,
              }
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'ok': true, 'data': {}}), 200);
      }),
      renewToken: (jwt) => AppSessionRenewer(
        apiClient: api,
        localPrefs: LocalPrefs(),
        identityBloc: identity,
      )(jwt),
    );
    return api;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({'app_refresh_token': 'stored'});
    identity = IdentityBloc();
  });

  test('renews through /app-auth/refresh, rotates the stored refresh token, '
      'and never touches the panel route', () async {
    final api = client(refreshOk: true)..setToken(_jwtExpiringIn(const Duration(seconds: 30)));

    await api.get('/app-ratings/me');

    expect(requests.map((r) => r.url.path), ['/app-auth/refresh', '/app-ratings/me']);
    expect(jsonDecode(requests.first.body), {'refreshToken': 'stored'});
    expect(shouldRenewJwt(api.token!), isFalse);
    expect(await LocalPrefs().getAppRefreshToken(), 'rotated');
    // The identity carries the fresh access token too.
    await Future<void>.delayed(Duration.zero);
    expect(identity.state.token, api.token);
  });

  test('a dead refresh token clears the stored session and lets the call proceed',
      () async {
    final stale = _jwtExpiringIn(const Duration(seconds: 30));
    final api = client(refreshOk: false)..setToken(stale);

    await api.get('/app-ratings/me');

    expect(requests.map((r) => r.url.path), ['/app-auth/refresh', '/app-ratings/me']);
    expect(api.token, stale);
    expect(await LocalPrefs().getAppRefreshToken(), isNull);
  });

  test('no stored refresh token: nothing is attempted', () async {
    SharedPreferences.setMockInitialValues({});
    final api = client(refreshOk: true)..setToken(_jwtExpiringIn(const Duration(seconds: 30)));

    await api.get('/app-ratings/me');

    expect(requests.map((r) => r.url.path), ['/app-ratings/me']);
  });
}
