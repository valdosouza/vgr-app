import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// The 8-point compass direction sighted for a fleeing subject (DS front,
/// round 15, decisions 200-207). Lives in `packages/core` because both
/// the `report` module (the read-only `directionEstimate` facet) and the
/// `direction_sighting` module (the write path) need the identical type
/// — the same reason `RiskTier` lives here (a module never imports
/// another module, `docs/adr/ARCHITECTURE.md`).
void main() {
  group('Direction wire mapping', () {
    test('every value round-trips through its own wire code', () {
      const expected = {
        Direction.n: 'N',
        Direction.ne: 'NE',
        Direction.e: 'E',
        Direction.se: 'SE',
        Direction.s: 'S',
        Direction.sw: 'SW',
        Direction.w: 'W',
        Direction.nw: 'NW',
      };

      for (final entry in expected.entries) {
        expect(entry.key.wire, entry.value);
        expect(DirectionJson.fromJson(entry.value), entry.key);
        expect(entry.key.toJson(), entry.value);
      }
    });

    test('fromJson is the exact inverse of toJson for every value', () {
      for (final direction in Direction.values) {
        expect(DirectionJson.fromJson(direction.toJson()), direction);
      }
    });
  });
}
