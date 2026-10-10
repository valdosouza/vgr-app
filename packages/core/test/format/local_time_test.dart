import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the device would show for [iso] — the test runs in whatever zone
/// the machine has, so the expectation is computed the same way.
String _expected(String iso, {bool withTime = true}) {
  final l = DateTime.parse(iso).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  final date = '${l.year}-${two(l.month)}-${two(l.day)}';
  return withTime ? '$date ${two(l.hour)}:${two(l.minute)}' : date;
}

void main() {
  group('formatLocalDateTime — UTC from the API, local on screen (decision 232)', () {
    test('converts a UTC instant to the device zone', () {
      const iso = '2026-10-04T21:38:41.000Z';
      expect(formatLocalDateTime(iso), _expected(iso));
    });

    test('honours an explicit offset', () {
      const iso = '2026-10-04T18:38:00-03:00';
      expect(formatLocalDateTime(iso), _expected(iso));
      // Same instant as 21:38 UTC.
      expect(formatLocalDateTime(iso), formatLocalDateTime('2026-10-04T21:38:00Z'));
    });

    test('crosses the day boundary when the zone says so', () {
      const iso = '2026-10-05T01:30:00Z';
      expect(formatLocalDateTime(iso), _expected(iso));
      expect(formatLocalDate(iso), _expected(iso, withTime: false));
    });

    test('null or blank reads as the empty mark', () {
      expect(formatLocalDateTime(null), '—');
      expect(formatLocalDateTime('  '), '—');
      expect(formatLocalDate(null, empty: ''), '');
    });

    test('a zone-less or date-only value is shown as served, never guessed', () {
      expect(formatLocalDateTime('2026-10-04T21:38:41'), '2026-10-04 21:38');
      expect(formatLocalDateTime('2026-10-04'), '2026-10-04');
      expect(formatLocalDate('2026-10-04'), '2026-10-04');
    });

    test('garbage is shown verbatim', () {
      expect(formatLocalDateTime('soon'), 'soon');
    });
  });

  group('localDayStartUtc / localDayEndUtc — the typed day is the local day (decision 235)', () {
    test('start is local midnight and end the last millisecond of the local day, both in UTC', () {
      expect(localDayStartUtc('2026-10-04'), DateTime(2026, 10, 4).toUtc().toIso8601String());
      expect(localDayEndUtc('2026-10-04'), DateTime(2026, 10, 4, 23, 59, 59, 999).toUtc().toIso8601String());
      expect(localDayStartUtc('2026-10-04'), endsWith('Z'));
    });

    test('the two bounds are exactly one local day apart', () {
      final start = DateTime.parse(localDayStartUtc('2026-03-08')!);
      final end = DateTime.parse(localDayEndUtc('2026-03-08')!);
      expect(end.add(const Duration(milliseconds: 1)), DateTime(2026, 3, 9).toUtc());
      expect(start, DateTime(2026, 3, 8).toUtc());
    });

    test('not a day — garbage, a date-time, an impossible date — gives null', () {
      for (final bad in ['', 'soon', '2026-10-04T10:00:00Z', '2026-02-30', '04/10/2026']) {
        expect(localDayStartUtc(bad), isNull, reason: bad);
        expect(localDayEndUtc(bad), isNull, reason: bad);
      }
    });
  });
}
