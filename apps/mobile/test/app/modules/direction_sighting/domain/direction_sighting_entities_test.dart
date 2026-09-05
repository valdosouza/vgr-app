import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vgr_mobile/app/modules/direction_sighting/domain/entity/direction_sighting_entities.dart';

/// Parsing of the DS2 write response (`api/docs/feature/
/// direction-sightings.md`): `POST /app-direction-sightings` ALWAYS
/// answers `{ sightingId, reportId, estimate, count }`, UNGATED by the
/// disclosure floor (202) — private, synchronous feedback to the actor
/// who just acted (decisions 22/200-207). Never confuse this with the
/// shared READ facet (`ReportViewEntity`/`FeedItemEntity.directionEstimate`
/// — count/distribution NEVER appear there, 203).
void main() {
  group('DirectionSightingResult.fromJson', () {
    test('maps every field of the write response', () {
      final result = DirectionSightingResult.fromJson({
        'sightingId': 501,
        'reportId': 7,
        'estimate': 'N',
        'count': 6,
      });

      expect(result.sightingId, 501);
      expect(result.reportId, 7);
      expect(result.estimate, Direction.n);
      expect(result.count, 6);
    });

    test('estimate can be null (e.g. a tie not yet resolved) — ungated by the floor either way', () {
      final result = DirectionSightingResult.fromJson({
        'sightingId': 1,
        'reportId': 7,
        'estimate': null,
        'count': 1,
      });

      expect(result.estimate, isNull);
      expect(result.count, 1);
    });
  });

  group('SightOutcome (mirrors SubmitOutcome/RateOutcome — decision 28)', () {
    test('online carries the accepted DirectionSightingResult', () {
      const result = DirectionSightingResult(
          sightingId: 1, reportId: 7, estimate: Direction.n, count: 6);
      const outcome = SightOutcome.online(result);

      expect(outcome.queued, isFalse);
      expect(outcome.result, result);
    });

    test('queued carries no result — no synchronous feedback exists for a queued write', () {
      const outcome = SightOutcome.queued();

      expect(outcome.queued, isTrue);
      expect(outcome.result, isNull);
    });
  });
}
