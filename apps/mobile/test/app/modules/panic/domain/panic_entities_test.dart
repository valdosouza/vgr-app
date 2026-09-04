import 'package:flutter_test/flutter_test.dart';
import 'package:vgr_mobile/app/modules/panic/domain/entity/panic_entities.dart';

/// Parsing of PP2's entity shapes (`api/docs/feature/panic.md`):
/// `POST /app-panic/alert` -> `{ alertId, createdAt, recipientCount }`
/// (decision 191, single shot), `GET /app-panic/alerts` rows ->
/// `{ alertId, distanceKm, createdAt, resolved }` (decision 195, distance
/// already rounded server-side) and `POST /app-panic/responder-pool` ->
/// `{ id, userId, status, criteriaNotes, requestedAt, resolvedAt,
/// resolvedBy }` (decision 190).
void main() {
  group('TriggeredAlertEntity.fromJson', () {
    test('maps the trigger response — never a lat/lng echo (identity minimization)', () {
      final alert = TriggeredAlertEntity.fromJson({
        'alertId': 42,
        'createdAt': '2026-09-04T10:00:00.000Z',
        'recipientCount': 3,
      });

      expect(alert.alertId, 42);
      expect(alert.createdAt, '2026-09-04T10:00:00.000Z');
      expect(alert.recipientCount, 3);
    });

    test('recipientCount 0 is valid — an empty pool never refuses the trigger (65)', () {
      final alert = TriggeredAlertEntity.fromJson({
        'alertId': 1,
        'createdAt': 'now',
        'recipientCount': 0,
      });

      expect(alert.recipientCount, 0);
    });
  });

  group('ResponderAlertEntity.fromJson', () {
    test('maps one inbox row, distance already rounded server-side (195)', () {
      final row = ResponderAlertEntity.fromJson({
        'alertId': 7,
        'distanceKm': 2.0,
        'createdAt': '2026-09-04T09:00:00.000Z',
        'resolved': false,
      });

      expect(row.alertId, 7);
      expect(row.distanceKm, 2.0);
      expect(row.createdAt, '2026-09-04T09:00:00.000Z');
      expect(row.resolved, isFalse);
    });

    test('a resolved row still renders — read only, no action ever (197)', () {
      final row = ResponderAlertEntity.fromJson({
        'alertId': 7,
        'distanceKm': 1.0,
        'createdAt': 'now',
        'resolved': true,
      });

      expect(row.resolved, isTrue);
    });
  });

  group('ResponderRequestEntity.fromJson (decision 190)', () {
    test('maps the pending pool-membership response', () {
      final request = ResponderRequestEntity.fromJson({
        'id': 3,
        'userId': 11,
        'status': 'pending',
        'criteriaNotes': 'volunteer firefighter',
        'requestedAt': '2026-09-04T08:00:00.000Z',
        'resolvedAt': null,
        'resolvedBy': null,
      });

      expect(request.id, 3);
      expect(request.userId, 11);
      expect(request.status, 'pending');
      expect(request.criteriaNotes, 'volunteer firefighter');
      expect(request.resolvedAt, isNull);
    });

    test('criteriaNotes is optional', () {
      final request = ResponderRequestEntity.fromJson({
        'id': 3,
        'userId': 11,
        'status': 'pending',
        'criteriaNotes': null,
        'requestedAt': 'now',
        'resolvedAt': null,
        'resolvedBy': null,
      });

      expect(request.criteriaNotes, isNull);
    });
  });

  group('TriggerOutcome (mirrors SubmitOutcome/RateOutcome, decision 28)', () {
    test('online carries the accepted TriggeredAlertEntity', () {
      const alert = TriggeredAlertEntity(alertId: 1, createdAt: 'now', recipientCount: 2);
      const outcome = TriggerOutcome.online(alert);

      expect(outcome.queued, isFalse);
      expect(outcome.alert, alert);
    });

    test('queued carries no alert yet — settles only when the queue flushes', () {
      const outcome = TriggerOutcome.queued();

      expect(outcome.queued, isTrue);
      expect(outcome.alert, isNull);
    });
  });
}
