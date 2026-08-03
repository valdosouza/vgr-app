import 'package:flutter_test/flutter_test.dart';
import 'package:core/src/error/failure.dart';

void main() {
  group('Failure', () {
    test('two instances with the same message and statusCode are equal', () {
      const a = Failure(message: 'Forbidden', statusCode: 403);
      const b = Failure(message: 'Forbidden', statusCode: 403);
      expect(a, equals(b));
    });

    test('two instances with different messages are not equal', () {
      const a = Failure(message: 'Forbidden', statusCode: 403);
      const b = Failure(message: 'Not found', statusCode: 404);
      expect(a, isNot(equals(b)));
    });

    test('statusCode is optional, defaulting to null for client-side failures', () {
      const failure = Failure(message: 'No connectivity');
      expect(failure.statusCode, isNull);
    });
  });
}
