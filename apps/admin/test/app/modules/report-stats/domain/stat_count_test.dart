import 'package:flutter_test/flutter_test.dart';
import 'package:vgr_admin/app/modules/report-stats/domain/entity/report_stats_entities.dart';

/// B4 (decision 164): every count the API serves is `number | "<5"`. The
/// value type is the ONE place the panel interprets that union.
void main() {
  group('StatCount.fromJson', () {
    test('a number is a value', () {
      final count = StatCount.fromJson(12);
      expect(count.value, 12);
      expect(count.belowFloor, isFalse);
    });

    test('0 stays 0 — never floored (164)', () {
      final count = StatCount.fromJson(0);
      expect(count.value, 0);
      expect(count.belowFloor, isFalse);
      expect(count.isZero, isTrue);
    });

    test('"<5" is below the floor and has no value', () {
      final count = StatCount.fromJson('<5');
      expect(count.value, isNull);
      expect(count.belowFloor, isTrue);
      expect(count.isZero, isFalse);
    });

    test('a numeric string from a lenient JSON encoder is still a value', () {
      expect(StatCount.fromJson('7').value, 7);
    });

    test('anything else is rejected — the panel never invents a count', () {
      expect(() => StatCount.fromJson('few'), throwsFormatException);
      expect(() => StatCount.fromJson(null), throwsFormatException);
    });
  });

  group('StatCount.label', () {
    test('renders the number or the floor marker', () {
      expect(const StatCount(value: 42).label(), '42');
      expect(const StatCount(value: 0).label(), '0');
      expect(const StatCount.belowFloor().label(), '<5');
    });
  });

  test('totals know when everything is zero (empty state)', () {
    final zero = StatsTotalsEntity.fromJson({
      'reports': 0, 'open': 0, 'resolved': 0, 'anonymous': 0, 'identified': 0,
      'frozen': 0, 'hidden': 0, 'expired': 0, 'purged': 0, 'withMedia': 0,
    });
    final floored = StatsTotalsEntity.fromJson({
      'reports': '<5', 'open': 0, 'resolved': 0, 'anonymous': 0, 'identified': 0,
      'frozen': 0, 'hidden': 0, 'expired': 0, 'purged': 0, 'withMedia': 0,
    });

    expect(zero.allZero, isTrue);
    // "<5" means 1..4 exist — that is NOT empty.
    expect(floored.allZero, isFalse);
  });
}
