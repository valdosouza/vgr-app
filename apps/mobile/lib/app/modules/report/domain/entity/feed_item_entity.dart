import 'package:equatable/equatable.dart';

import '../gateway/location_gateway.dart';

/// Feed ordering (decision 21) — deterministic and documented server-side.
enum FeedOrder { recency, relevance }

/// One `GET /app-feed` item. Everything here is already DEGRADED by tier
/// (decision 135): the grid position, the snapped distance, the bucketed
/// timestamp. The app renders what it gets and never sharpens it.
class FeedItemEntity extends Equatable {
  const FeedItemEntity({
    required this.reportId,
    this.category,
    this.freeTag,
    required this.subject,
    required this.tier,
    required this.position,
    required this.distanceKm,
    required this.createdAt,
  });

  final int reportId;
  final String? category;
  final String? freeTag;
  final String subject;
  final String tier;
  final GeoPoint position;
  final double distanceKm;

  /// Degraded ISO timestamp (minute/15min/hour bucket by tier).
  final String createdAt;

  factory FeedItemEntity.fromJson(Map<String, dynamic> json) => FeedItemEntity(
        reportId: json['reportId'] as int,
        category: json['category'] as String?,
        freeTag: json['freeTag'] as String?,
        subject: json['subject'] as String,
        tier: json['tier'] as String,
        position: GeoPoint(
          lat: ((json['position'] as Map)['lat'] as num).toDouble(),
          lng: ((json['position'] as Map)['lng'] as num).toDouble(),
        ),
        distanceKm: (json['distanceKm'] as num).toDouble(),
        createdAt: json['createdAt'] as String,
      );

  @override
  List<Object?> get props =>
      [reportId, category, freeTag, subject, tier, position, distanceKm, createdAt];
}

class FeedPageEntity extends Equatable {
  const FeedPageEntity({
    required this.items,
    required this.page,
    required this.hasMore,
    required this.order,
  });

  final List<FeedItemEntity> items;
  final int page;
  final bool hasMore;
  final FeedOrder order;

  factory FeedPageEntity.fromJson(Map<String, dynamic> json) => FeedPageEntity(
        items: (json['items'] as List<dynamic>)
            .map((i) => FeedItemEntity.fromJson((i as Map).cast<String, dynamic>()))
            .toList(),
        page: json['page'] as int,
        hasMore: json['hasMore'] as bool,
        order: json['order'] == 'relevance' ? FeedOrder.relevance : FeedOrder.recency,
      );

  @override
  List<Object?> get props => [items, page, hasMore, order];
}
