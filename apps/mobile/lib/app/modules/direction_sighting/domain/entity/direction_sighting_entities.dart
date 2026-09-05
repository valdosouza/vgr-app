import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

/// Entities of the DS2 direction-sighting front (decisions 200-207),
/// mapped 1:1 from `api/docs/feature/direction-sightings.md`.

/// The write response of `POST /app-direction-sightings` — a deliberate
/// write/read asymmetry (decisions 22/203): private, SYNCHRONOUS feedback
/// to the actor who just logged a sighting, carrying MORE than any READ
/// path ever does. `estimate`/`count` exist ONLY here, UNGATED by the
/// disclosure floor (202) that gates the shared READ facet
/// (`ReportViewEntity`/`FeedItemEntity.directionEstimate`) — never confuse
/// the two, and never read `count` from anywhere else.
class DirectionSightingResult extends Equatable {
  const DirectionSightingResult({
    required this.sightingId,
    required this.reportId,
    required this.estimate,
    required this.count,
  });

  final int sightingId;
  final int reportId;

  /// The single winning direction so far — never the underlying
  /// distribution (203's minimal-disclosure principle applies here too).
  final Direction? estimate;

  /// Total sightings so far, any direction — exists ONLY in this write
  /// response, never on a READ path.
  final int count;

  factory DirectionSightingResult.fromJson(Map<String, dynamic> json) =>
      DirectionSightingResult(
        sightingId: json['sightingId'] as int,
        reportId: json['reportId'] as int,
        estimate:
            json['estimate'] == null ? null : DirectionJson.fromJson(json['estimate'] as String),
        count: json['count'] as int,
      );

  @override
  List<Object?> get props => [sightingId, reportId, estimate, count];
}

/// Result of [DirectionSightingRepository.logSighting] — mirrors
/// `SubmitOutcome`/`RateOutcome`: `online` carries the server's
/// synchronous [DirectionSightingResult]; `queued` means a transport
/// failure enqueued it for later (decision 28 — a sighting survives being
/// offline exactly like every other write in this app). A queued sighting
/// has NO immediate estimate/count to show — that private feedback only
/// ever exists on the synchronous online response.
class SightOutcome extends Equatable {
  const SightOutcome.online(DirectionSightingResult this.result) : queued = false;
  const SightOutcome.queued()
      : result = null,
        queued = true;

  final DirectionSightingResult? result;
  final bool queued;

  @override
  List<Object?> get props => [result, queued];
}
