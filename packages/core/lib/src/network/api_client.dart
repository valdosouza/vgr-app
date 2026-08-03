import 'dart:convert';

import 'package:http/http.dart' as http;

import '../error/failure.dart';

/// Thin HTTP wrapper shared by every feature module's data layer (mobile
/// and admin). Decodes the API's `{ ok, data }` / `{ error, code, fields }`
/// envelope and throws a [Failure] for any non-2xx response, so
/// repositories only ever deal with `Either<Failure, T>`.
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;
  String? _token;

  /// Sets the token used automatically by every subsequent call that
  /// doesn't pass an explicit `token` — set once after login so existing
  /// repositories never need to thread it through themselves.
  void setToken(String? token) => _token = token;

  Future<Map<String, dynamic>> get(String path, {String? token}) async {
    final response = await _httpClient.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers(token),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final response = await _httpClient.put(
      Uri.parse('$baseUrl$path'),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Map<String, String> _headers(String? token) {
    final effectiveToken = token ?? _token;
    return {
      'Content-Type': 'application/json',
      if (effectiveToken != null) 'Authorization': 'Bearer $effectiveToken',
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
    );
  }
}
