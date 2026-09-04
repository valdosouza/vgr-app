import 'package:equatable/equatable.dart';

/// Entities of the RT2 helper-rating front (decisions 48/178-189), mapped
/// 1:1 from `api/docs/feature/rating.md`.

/// One accepted rating (`POST /app-reports/:reportId/offers/:offerId/
/// rating` response) — immutable once given, no PUT/DELETE exists (183).
class RatingEntity extends Equatable {
  const RatingEntity({
    required this.ratingId,
    required this.reportId,
    required this.helpOfferId,
    required this.score,
    required this.createdAt,
  });

  final int ratingId;
  final int reportId;
  final int helpOfferId;
  final int score;
  final String createdAt;

  factory RatingEntity.fromJson(Map<String, dynamic> json) => RatingEntity(
        ratingId: json['ratingId'] as int,
        reportId: json['reportId'] as int,
        helpOfferId: json['helpOfferId'] as int,
        score: json['score'] as int,
        createdAt: json['createdAt'] as String,
      );

  @override
  List<Object?> get props => [ratingId, reportId, helpOfferId, score, createdAt];
}

/// The caller's OWN aggregate (`GET /app-ratings/me`, decisions 184/185):
/// `count` always, `average` null below the k-anonymity floor the API
/// already enforced — the app never recomputes that rule, only renders
/// what came back.
class ReputationEntity extends Equatable {
  const ReputationEntity({required this.count, this.average});

  final int count;
  final double? average;

  factory ReputationEntity.fromJson(Map<String, dynamic> json) => ReputationEntity(
        count: json['count'] as int,
        average: (json['average'] as num?)?.toDouble(),
      );

  @override
  List<Object?> get props => [count, average];
}

/// Result of [RatingRepository.rateOffer] — mirrors `SubmitOutcome`
/// (report_input.dart): `online` carries the server's accepted [Rating];
/// `queued` means a transport failure enqueued it for later (decision 181
/// — a rating survives offline exactly like a report submission does, 28).
class RateOutcome extends Equatable {
  const RateOutcome.online(RatingEntity this.rating) : queued = false;
  const RateOutcome.queued()
      : rating = null,
        queued = true;

  final RatingEntity? rating;
  final bool queued;

  @override
  List<Object?> get props => [rating, queued];
}
