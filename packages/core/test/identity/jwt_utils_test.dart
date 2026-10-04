import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

String _jwt(Map<String, dynamic> payload) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode(payload)))}.signature';

void main() {
  group('sessionUserIdOf — the actor the API will see (decision 227)', () {
    test('reads the userId claim of the session token', () {
      expect(sessionUserIdOf(_jwt({'userId': 7, 'role': 'admin', 'sv': 1})), 7);
    });

    test('null without a token, without the claim, or with a malformed token', () {
      expect(sessionUserIdOf(null), isNull);
      expect(sessionUserIdOf(_jwt({'role': 'admin'})), isNull);
      expect(sessionUserIdOf(_jwt({'userId': 'seven'})), isNull);
      expect(sessionUserIdOf('not-a-jwt'), isNull);
    });
  });
}
