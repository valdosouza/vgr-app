import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vgr_mobile/app/modules/direction_sighting/data/direction_sighting_local_store.dart';

/// Local-only "did THIS device already sight this report" record (DS2 —
/// decisions 200-207). Mirrors `PanicLocalStore`'s shape — no server
/// endpoint exists to read this back (the API contract's own documented
/// gap). A SOFT, UX-level spam mitigation, NOT a real security boundary:
/// a reinstall or a second device bypasses it entirely, same posture as
/// `PanicLocalStore.responderRequestSent`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DirectionSightingLocalStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = DirectionSightingLocalStore(prefs: prefs);
  });

  test('nothing saved yet -> null', () async {
    expect(await store.sightingFor(5), isNull);
  });

  test('save then read back the same direction', () async {
    await store.saveSighting(reportId: 5, direction: Direction.ne);

    expect(await store.sightingFor(5), Direction.ne);
  });

  test('records are independent per report', () async {
    await store.saveSighting(reportId: 5, direction: Direction.n);
    await store.saveSighting(reportId: 9, direction: Direction.sw);

    expect(await store.sightingFor(5), Direction.n);
    expect(await store.sightingFor(9), Direction.sw);
    expect(await store.sightingFor(1), isNull);
  });

  test('a second save for the SAME report replaces the first (defensive — the bloc '
      'never re-offers the picker once sighted, so this should not normally happen)',
      () async {
    await store.saveSighting(reportId: 5, direction: Direction.n);
    await store.saveSighting(reportId: 5, direction: Direction.s);

    expect(await store.sightingFor(5), Direction.s);
  });

  test('survives a fresh store instance over the same prefs (app restart)', () async {
    await store.saveSighting(reportId: 5, direction: Direction.e);
    final prefs = await SharedPreferences.getInstance();

    final reopened = DirectionSightingLocalStore(prefs: prefs);

    expect(await reopened.sightingFor(5), Direction.e);
  });
}
