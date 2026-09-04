import 'package:flutter_test/flutter_test.dart';
import 'package:vgr_mobile/app/modules/rating/domain/entity/rating_entities.dart';

/// Parsing of the RT2 write/read shapes (`api/docs/feature/rating.md`):
/// `Rating { ratingId, reportId, helpOfferId, score, createdAt }` and
/// `GET /app-ratings/me` → `{ count, average }` (decisions 182-184).
void main() {
  group('RatingEntity.fromJson', () {
    test('maps every field of the accepted-rating response', () {
      final rating = RatingEntity.fromJson({
        'ratingId': 1,
        'reportId': 5,
        'helpOfferId': 9,
        'score': 4,
        'createdAt': '2026-09-04T10:00:00.000Z',
      });

      expect(rating.ratingId, 1);
      expect(rating.reportId, 5);
      expect(rating.helpOfferId, 9);
      expect(rating.score, 4);
      expect(rating.createdAt, '2026-09-04T10:00:00.000Z');
    });
  });

  group('ReputationEntity.fromJson (decision 184)', () {
    test('below the k-anonymity floor: count only, average null', () {
      final reputation = ReputationEntity.fromJson({'count': 2, 'average': null});

      expect(reputation.count, 2);
      expect(reputation.average, isNull);
    });

    test('at/above the floor: average is a rounded double, never recomputed by the app', () {
      final reputation = ReputationEntity.fromJson({'count': 7, 'average': 4.29});

      expect(reputation.count, 7);
      expect(reputation.average, 4.29);
    });

    test('an integral average still parses as a double', () {
      final reputation = ReputationEntity.fromJson({'count': 5, 'average': 5});

      expect(reputation.average, 5.0);
    });
  });

  group('RateOutcome (mirrors SubmitOutcome — decision 181)', () {
    test('online carries the accepted Rating', () {
      const rating = RatingEntity(
        ratingId: 1, reportId: 5, helpOfferId: 9, score: 4, createdAt: 'now');
      const outcome = RateOutcome.online(rating);

      expect(outcome.queued, isFalse);
      expect(outcome.rating, rating);
    });

    test('queued carries no rating yet — settles only when the queue flushes', () {
      const outcome = RateOutcome.queued();

      expect(outcome.queued, isTrue);
      expect(outcome.rating, isNull);
    });
  });
}
