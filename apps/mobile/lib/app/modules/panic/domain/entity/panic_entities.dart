import 'package:equatable/equatable.dart';

/// Entities of the PP2 panic-button front (decisions 62/65/191/196-198),
/// mapped 1:1 from `api/docs/feature/panic.md`.

/// `POST /app-panic/alert` response — 201 first accept, 200 on a replay of
/// the same `clientKey` (137), same shape either way. Single shot (191):
/// the position captured at trigger is never echoed back or updated —
/// this entity intentionally carries no `lat`/`lng` (identity/position
/// minimization, the API never serves the raw trigger position either).
class TriggeredAlertEntity extends Equatable {
  const TriggeredAlertEntity({
    required this.alertId,
    required this.createdAt,
    required this.recipientCount,
  });

  final int alertId;
  final String createdAt;

  /// May legitimately be 0 — an empty responder pool never refuses the
  /// trigger (decision 65).
  final int recipientCount;

  factory TriggeredAlertEntity.fromJson(Map<String, dynamic> json) => TriggeredAlertEntity(
        alertId: json['alertId'] as int,
        createdAt: json['createdAt'] as String,
        recipientCount: json['recipientCount'] as int,
      );

  @override
  List<Object?> get props => [alertId, createdAt, recipientCount];
}

/// One row of `GET /app-panic/alerts` (the responder's own inbox) —
/// `distanceKm` arrives already rounded server-side via
/// `DISTANCE_STEP_BY_TIER.high` (decision 195, the most protective step:
/// a panic alert has no Category/RiskTierConfig to look a tier up from).
/// The fixed client-side template (decision 196) is rendered from
/// `{alertId, distanceKm}` only — this entity carries no free text because
/// the API never stores or serves any for a panic alert.
class ResponderAlertEntity extends Equatable {
  const ResponderAlertEntity({
    required this.alertId,
    required this.distanceKm,
    required this.createdAt,
    required this.resolved,
  });

  final int alertId;
  final double distanceKm;
  final String createdAt;

  /// Whether the TRIGGERER already resolved it (197) — a responder can
  /// never resolve someone else's alert, so this is read-only here.
  final bool resolved;

  factory ResponderAlertEntity.fromJson(Map<String, dynamic> json) => ResponderAlertEntity(
        alertId: json['alertId'] as int,
        distanceKm: (json['distanceKm'] as num).toDouble(),
        createdAt: json['createdAt'] as String,
        resolved: json['resolved'] as bool,
      );

  @override
  List<Object?> get props => [alertId, distanceKm, createdAt, resolved];
}

/// `POST /app-panic/responder-pool` response (decision 190 — eligibility
/// is free human judgment by an admin, not codified; `status` starts
/// `pending` and this app has no endpoint to poll it later, see
/// `app/docs/feature/panic.md`).
class ResponderRequestEntity extends Equatable {
  const ResponderRequestEntity({
    required this.id,
    required this.userId,
    required this.status,
    this.criteriaNotes,
    required this.requestedAt,
    this.resolvedAt,
    this.resolvedBy,
  });

  final int id;
  final int userId;
  final String status;
  final String? criteriaNotes;
  final String requestedAt;
  final String? resolvedAt;
  final int? resolvedBy;

  factory ResponderRequestEntity.fromJson(Map<String, dynamic> json) => ResponderRequestEntity(
        id: json['id'] as int,
        userId: json['userId'] as int,
        status: json['status'] as String,
        criteriaNotes: json['criteriaNotes'] as String?,
        requestedAt: json['requestedAt'] as String,
        resolvedAt: json['resolvedAt'] as String?,
        resolvedBy: json['resolvedBy'] as int?,
      );

  @override
  List<Object?> get props =>
      [id, userId, status, criteriaNotes, requestedAt, resolvedAt, resolvedBy];
}

/// Result of [PanicRepository.trigger] — mirrors `SubmitOutcome`/
/// `RateOutcome`: `online` carries the server's accepted alert; `queued`
/// means a transport failure enqueued it for later (decision 28 — a panic
/// trigger survives offline exactly like a report submission does).
class TriggerOutcome extends Equatable {
  const TriggerOutcome.online(TriggeredAlertEntity this.alert) : queued = false;
  const TriggerOutcome.queued()
      : alert = null,
        queued = true;

  final TriggeredAlertEntity? alert;
  final bool queued;

  @override
  List<Object?> get props => [alert, queued];
}
