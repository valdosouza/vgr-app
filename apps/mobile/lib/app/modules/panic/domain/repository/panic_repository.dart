import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../report/domain/gateway/location_gateway.dart';
import '../entity/panic_entities.dart';

/// Contract of the PP2 panic-button front (decisions 62/65/191/196-198;
/// API contract in `api/docs/feature/panic.md`). Bound once in `AppModule`
/// (like `RatingRepository`/`MyReportsStore`) because it is reachable from
/// both the panic module (trigger/resolve/inbox) and the auth module's
/// account page (the responder-request tile).
abstract class PanicRepository {
  /// The locally-remembered alert THIS DEVICE triggered and has not yet
  /// resolved, if any — **no PP1 endpoint exists to read "my own
  /// triggered alert"** (a documented, accepted gap; see
  /// `app/docs/feature/panic.md`), so this is purely local bookkeeping
  /// surfaced through the repository contract (never touched directly by
  /// a bloc — decision 133's layering). Null after a successful
  /// [resolve], or if this device never triggered one (or lost the local
  /// record, e.g. a reinstall — see the gap above).
  Future<int?> currentActiveAlertId();

  /// `POST /app-panic/alert` — a cold trigger (65): no prior configuration,
  /// no free text (196). Generates its own `clientKey` and reads the
  /// device's position via [LocationGateway] internally, so a location
  /// failure (`LOCATION_OFF`/`LOCATION_DENIED`/`LOCATION_ERROR`) is a Left
  /// and the API is NEVER called. A `Failure` the API judged (422/451, or
  /// 409 `PANIC_ALERT_ACTIVE` — identified callers only, 198) is a Left
  /// and is NEVER enqueued, mirroring `ReportRepository.submit`/
  /// `RatingRepository.rateOffer`. A transport failure enqueues the
  /// trigger for later (decision 28) and returns a queued outcome.
  Future<Either<Failure, TriggerOutcome>> trigger();

  /// `POST /app-panic/alerts/:id/resolve` — only the triggerer (197): the
  /// repository reads the locally-stored `{alertId, clientKey}` to send
  /// `x-client-key` when the trigger was anonymous. Same two-tier online/
  /// offline shape as [trigger]. A 409 `PANIC_ALERT_ALREADY_RESOLVED` is
  /// treated as an effectively-successful resolve (the local record is
  /// cleared either way) — the same judgment call
  /// `report_queue_tasks.dart`'s `_judgeResolve` makes for a double-close:
  /// an ack that never reached this device after a first attempt DID
  /// succeed would otherwise strand the user on a permanently "active"
  /// screen for no product reason.
  Future<Either<Failure, void>> resolve(int alertId);

  /// `GET /app-panic/alerts?after&limit&lat&lng` — the caller's OWN
  /// responder inbox (a non-responder just gets an empty list forever,
  /// there is no separate "am I a responder" check). [position] is the
  /// RESPONDER's own current position, required by the server to compute
  /// `distanceKm` (the API never re-derives it from anything else). No
  /// offline queue — a read, like `RatingRepository.getMyReputation`.
  Future<Either<Failure, List<ResponderAlertEntity>>> listAlerts({
    required int after,
    required int limit,
    required GeoPoint position,
  });

  /// Whether THIS DEVICE already sent a responder-authorization request —
  /// purely local bookkeeping (the API has no uniqueness constraint
  /// against a repeat `POST`, see `panic.md`'s "Plane fix" section), read
  /// by the account page so it does not invite an accidental duplicate.
  Future<bool> responderRequestAlreadySent();

  /// `POST /app-panic/responder-pool` — an identified account's own
  /// request to join the pool (decision 190: eligibility is free human
  /// judgment by an admin, not codified here). No `criteriaNotes` is
  /// collected in this phase (193/194 keep per-user configuration out of
  /// scope). On success, persists the "already sent" flag locally so the
  /// account tile does not invite a second pending request — the API
  /// itself has no uniqueness constraint against repeats. No offline
  /// queue (an infrequent, identified-only action — same posture as
  /// `getMyReputation`).
  Future<Either<Failure, void>> requestResponderAuthorization();
}
