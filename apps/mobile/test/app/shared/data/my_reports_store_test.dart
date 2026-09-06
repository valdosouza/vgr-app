import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vgr_mobile/app/shared/data/my_reports_store.dart';

/// `MyReportsStore` lives in `app/shared/` because four modules (report,
/// chat, help_offer, rating) plus `AppModule` consume it, and a module never
/// imports another module (ARCHITECTURE.md). Promoted from
/// `modules/report/data/` on 2026-09-06 once the fourth consumer arrived.
///
/// The storage key is part of the contract: every report a user owns was
/// written under it, so renaming it would silently orphan those records.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MyReportsStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = MyReportsStore(prefs: prefs);
  });

  test('unknown report -> null (this device does not own it)', () async {
    expect(await store.clientKeyOf(7), isNull);
  });

  test('save then read back the clientKey of that report', () async {
    await store.save(7, 'ck-7');

    expect(await store.clientKeyOf(7), 'ck-7');
  });

  test('several owned reports are kept side by side', () async {
    await store.save(1, 'ck-1');
    await store.save(2, 'ck-2');

    expect(await store.clientKeyOf(1), 'ck-1');
    expect(await store.clientKeyOf(2), 'ck-2');
  });

  test('records written under `my_reports_v1` by an earlier build are still readable', () async {
    SharedPreferences.setMockInitialValues({'my_reports_v1': '{"42":"ck-42"}'});
    final prefs = await SharedPreferences.getInstance();

    final reopened = MyReportsStore(prefs: prefs);

    expect(await reopened.clientKeyOf(42), 'ck-42');
  });
}
