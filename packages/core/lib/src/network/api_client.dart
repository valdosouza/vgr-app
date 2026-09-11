import 'dart:convert';

import 'package:http/http.dart' as http;

import '../error/failure.dart';
import '../identity/jwt_utils.dart';

/// Thin HTTP wrapper shared by every feature module's data layer (mobile
/// and admin). Decodes the API's `{ ok, data }` / `{ error, code, fields }`
/// envelope and throws a [Failure] for any non-2xx response, so
/// repositories only ever deal with `Either<Failure, T>`.
///
/// Since decision 112 the session is 15 minutes, so this client renews it
/// silently: before any authenticated call whose token is about to expire,
/// it exchanges the current token. The default strategy is the panel's
/// `POST /api/auth/renew`; the app plane (decision 119 — separate
/// audiences, refresh tokens) injects its own via [renewToken]. Callers
/// see nothing; [onTokenRenewed] lets the app persist the fresh token.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
    this.onTokenRenewed,
    this.renewToken,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;
  String? _token;
  Future<void>? _pendingRenewal;

  /// Called with the new JWT whenever a silent renewal succeeds — the app
  /// persists it when "keep me signed in" is on (decision 73).
  final void Function(String jwt)? onTokenRenewed;

  /// Plane-specific renewal: given the current (about to expire) JWT,
  /// returns the fresh one, or null when the session cannot be renewed.
  /// May call back into this client — renewal is not re-entered
  /// meanwhile. Null keeps the panel's `/api/auth/renew` exchange.
  final Future<String?> Function(String currentJwt)? renewToken;

  bool _renewing = false;

  /// Sets the token used automatically by every subsequent call that
  /// doesn't pass an explicit `token` — set once after login so existing
  /// repositories never need to thread it through themselves.
  void setToken(String? token) => _token = token;

  String? get token => _token;

  /// Renews the stored token when it is within the renewal window
  /// (decision 112). Concurrent callers share one in-flight renewal, so a
  /// screen firing five requests at once does not fire five renewals.
  /// A failed renewal is swallowed: the request proceeds and the API
  /// answers 401, which the app already handles as "session over".
  Future<void> _ensureFreshToken(String? explicitToken) async {
    final current = _token;
    if (explicitToken != null || current == null || _renewing) return;
    if (!shouldRenewJwt(current)) return;

    _pendingRenewal ??= () async {
      _renewing = true;
      try {
        final jwt = renewToken != null
            ? await renewToken!(current)
            : await _exchangeAtPanelRoute(current);
        if (jwt != null) {
          _token = jwt;
          onTokenRenewed?.call(jwt);
        }
      } catch (_) {
        // Silent by design — see the doc comment above.
      } finally {
        _renewing = false;
        _pendingRenewal = null;
      }
    }();

    await _pendingRenewal;
  }

  Future<String?> _exchangeAtPanelRoute(String current) async {
    final response = await _httpClient.post(
      Uri.parse('$baseUrl/api/auth/renew'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $current'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    return (jsonDecode(response.body) as Map<String, dynamic>)['jwt'] as String?;
  }

  Future<Map<String, dynamic>> get(String path, {String? token, Map<String, String>? headers}) async {
    await _ensureFreshToken(token);
    final response = await _httpClient.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers(token, extra: headers),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
    Map<String, String>? headers,
  }) async {
    await _ensureFreshToken(token);
    final response = await _httpClient.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(token, extra: headers),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  /// Multipart upload — the `/app-media` contract (file field + text
  /// fields). Kept on the client so repositories stay `Either`-only.
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required String filePath,
    String fileField = 'file',
    Map<String, String> fields = const {},
    String? token,
  }) async {
    await _ensureFreshToken(token);
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'))
      ..fields.addAll(fields)
      ..files.add(await http.MultipartFile.fromPath(fileField, filePath));
    final effectiveToken = token ?? _token;
    if (effectiveToken != null) {
      request.headers['Authorization'] = 'Bearer $effectiveToken';
    }
    final response = await http.Response.fromStream(await _httpClient.send(request));
    return _decode(response);
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    await _ensureFreshToken(token);
    final response = await _httpClient.put(
      Uri.parse('$baseUrl$path'),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> delete(String path, {String? token}) async {
    await _ensureFreshToken(token);
    final response = await _httpClient.delete(
      Uri.parse('$baseUrl$path'),
      headers: _headers(token),
    );
    return _decode(response);
  }

  Map<String, String> _headers(String? token, {Map<String, String>? extra}) {
    final effectiveToken = token ?? _token;
    return {
      'Content-Type': 'application/json',
      if (effectiveToken != null) 'Authorization': 'Bearer $effectiveToken',
      ...?extra,
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    throw Failure(
      message: decoded['error'] as String? ?? 'Request failed',
      statusCode: response.statusCode,
      code: decoded['code'] as String?,
      fields: (decoded['fields'] as List<dynamic>?)
          ?.map((f) => FieldFailure.fromJson(f as Map<String, dynamic>))
          .toList(),
      params: (decoded['params'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, '$v')),
    );
  }
}
