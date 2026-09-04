import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vgr_mobile/app/modules/panic/data/panic_local_store.dart';

/// Local state for PP2 (mirrors `MyReportsStore`'s shape — the only other
/// "remember an id locally" pattern in this app, `SharedPreferences`-backed,
/// no generic reusable store exists in `packages/core`):
///
/// - the CURRENT unresolved alert THIS DEVICE triggered, if any — a
///   single record (never a map: only one active alert per device at a
///   time by construction, mirroring the server's own cooldown, 198), so
///   `resolve` can be called later even after an app restart.
/// - whether a responder-pool request was already sent from this device —
///   a pure UX nicety (the API has no uniqueness constraint on repeats)
///   so the account tile does not invite a second pending request on
///   every visit.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PanicLocalStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = PanicLocalStore(prefs: prefs);
  });

  group('active alert', () {
    test('nothing saved yet -> null', () async {
      expect(await store.activeAlert(), isNull);
    });

    test('save then read back the same alertId/clientKey', () async {
      await store.saveActiveAlert(alertId: 42, clientKey: 'ck-42');

      final active = await store.activeAlert();

      expect(active, isNotNull);
      expect(active!.alertId, 42);
      expect(active.clientKey, 'ck-42');
    });

    test('a second save REPLACES the first — only one active alert at a time', () async {
      await store.saveActiveAlert(alertId: 1, clientKey: 'ck-1');
      await store.saveActiveAlert(alertId: 2, clientKey: 'ck-2');

      final active = await store.activeAlert();

      expect(active!.alertId, 2);
      expect(active.clientKey, 'ck-2');
    });

    test('clearActiveAlert removes the record — back to offering the trigger button', () async {
      await store.saveActiveAlert(alertId: 42, clientKey: 'ck-42');

      await store.clearActiveAlert();

      expect(await store.activeAlert(), isNull);
    });

    test('survives a fresh store instance over the same prefs (app restart)', () async {
      await store.saveActiveAlert(alertId: 42, clientKey: 'ck-42');
      final prefs = await SharedPreferences.getInstance();

      final reopened = PanicLocalStore(prefs: prefs);

      final active = await reopened.activeAlert();
      expect(active!.alertId, 42);
    });
  });

  group('responder request flag', () {
    test('nothing sent yet -> false', () async {
      expect(await store.responderRequestSent(), isFalse);
    });

    test('markResponderRequestSent flips it to true and it persists', () async {
      await store.markResponderRequestSent();

      expect(await store.responderRequestSent(), isTrue);
    });

    test('the active-alert record and the responder flag are independent', () async {
      await store.saveActiveAlert(alertId: 42, clientKey: 'ck-42');
      await store.markResponderRequestSent();

      await store.clearActiveAlert();

      expect(await store.activeAlert(), isNull);
      expect(await store.responderRequestSent(), isTrue);
    });
  });
}
