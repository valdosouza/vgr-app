import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vgr_mobile/app/modules/report/domain/entity/feed_item_entity.dart';

Map<String, dynamic> _item({Map<String, dynamic>? directionEstimate}) => {
      'reportId': 1,
      'category': 'missing',
      'subject': 'child',
      'tier': 'medium',
      'position': {'lat': -23.5, 'lng': -46.6},
      'distanceKm': 1.5,
      'createdAt': '2026-08-04T18:15:00.000Z',
      if (directionEstimate != null) 'directionEstimate': directionEstimate,
    };

/// `FeedItemEntity.directionEstimate` — the SECOND place decision 204
/// requires the shared READ facet (the first is `ReportViewEntity`, see
/// `report_view_entity_test.dart`), parsed identically.
void main() {
  group('FeedItemEntity.directionEstimate (decisions 202-204)', () {
    test('absent → null, handled defensively (below the floor / ineligible category)', () {
      expect(FeedItemEntity.fromJson(_item()).directionEstimate, isNull);
    });

    test('present → the single winning Direction', () {
      final item = FeedItemEntity.fromJson(_item(directionEstimate: {'direction': 'NW'}));
      expect(item.directionEstimate, Direction.nw);
    });

    test('it takes part in equality', () {
      final withEstimate =
          FeedItemEntity.fromJson(_item(directionEstimate: {'direction': 'W'}));
      expect(withEstimate, isNot(FeedItemEntity.fromJson(_item())));
    });
  });
}
