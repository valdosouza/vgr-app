import 'package:equatable/equatable.dart';

import '../gateway/location_gateway.dart';

/// Who the server judged the viewer to be (GetReportVisibility,
/// decision 50). The APP never computes this — it renders what it got.
enum ReportAccess { owner, participant, public, summary }

class TimelineEventEntity extends Equatable {
  const TimelineEventEntity({
    required this.eventType,
    this.payload,
    required this.createdAt,
  });

  final String eventType;
  final Map<String, dynamic>? payload;
  final String createdAt;

  factory TimelineEventEntity.fromJson(Map<String, dynamic> json) => TimelineEventEntity(
        eventType: json['eventType'] as String,
        payload: (json['payload'] as Map?)?.cast<String, dynamic>(),
        createdAt: json['createdAt'] as String,
      );

  @override
  List<Object?> get props => [eventType, payload, createdAt];
}

class ReportMediaRefEntity extends Equatable {
  const ReportMediaRefEntity({required this.publicId, this.mime, this.width, this.height});

  final String publicId;
  final String? mime;
  final int? width;
  final int? height;

  factory ReportMediaRefEntity.fromJson(Map<String, dynamic> json) => ReportMediaRefEntity(
        publicId: json['publicId'] as String,
        mime: json['mime'] as String?,
        width: json['width'] as int?,
        height: json['height'] as int?,
      );

  @override
  List<Object?> get props => [publicId, mime, width, height];
}

/// Offer row as the OWNER sees it — identity only when the helper chose
/// it and the tier allows (6/40/60); no timestamp on high tier (41).
class OfferViewEntity extends Equatable {
  const OfferViewEntity({
    required this.helpOfferId,
    required this.helpType,
    this.helperDisplayName,
    this.createdAt,
  });

  final int helpOfferId;
  final String helpType;
  final String? helperDisplayName;
  final String? createdAt;

  factory OfferViewEntity.fromJson(Map<String, dynamic> json) => OfferViewEntity(
        helpOfferId: json['helpOfferId'] as int,
        helpType: json['helpType'] as String,
        helperDisplayName: json['helperDisplayName'] as String?,
        createdAt: json['createdAt'] as String?,
      );

  @override
  List<Object?> get props => [helpOfferId, helpType, helperDisplayName, createdAt];
}

/// `GET /app-reports/:id` — shape varies by [access]; absent facets are
/// null (a summary has no timeline, a public view has no offers, etc.).
class ReportViewEntity extends Equatable {
  const ReportViewEntity({
    required this.access,
    required this.reportId,
    this.category,
    this.freeTag,
    required this.subject,
    required this.tier,
    required this.status,
    this.position,
    this.detailFields,
    this.createdAt,
    this.resolvedAt,
    this.timeline,
    this.media = const [],
    this.offers,
  });

  final ReportAccess access;
  final int reportId;
  final String? category;
  final String? freeTag;
  final String subject;
  final String tier;
  final String status;
  final GeoPoint? position;
  final Map<String, dynamic>? detailFields;
  final String? createdAt;
  final String? resolvedAt;
  final List<TimelineEventEntity>? timeline;
  final List<ReportMediaRefEntity> media;
  final List<OfferViewEntity>? offers;

  factory ReportViewEntity.fromJson(Map<String, dynamic> json) {
    final position = json['position'] as Map?;
    return ReportViewEntity(
      access: ReportAccess.values.byName(json['access'] as String),
      reportId: json['reportId'] as int,
      category: json['category'] as String?,
      freeTag: json['freeTag'] as String?,
      subject: json['subject'] as String,
      tier: json['tier'] as String,
      status: json['status'] as String,
      position: position == null
          ? null
          : GeoPoint(
              lat: (position['lat'] as num).toDouble(),
              lng: (position['lng'] as num).toDouble(),
            ),
      detailFields: (json['detailFields'] as Map?)?.cast<String, dynamic>(),
      createdAt: json['createdAt'] as String?,
      resolvedAt: json['resolvedAt'] as String?,
      timeline: (json['timeline'] as List<dynamic>?)
          ?.map((e) => TimelineEventEntity.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      media: (json['media'] as List<dynamic>? ?? const [])
          .map((m) => ReportMediaRefEntity.fromJson((m as Map).cast<String, dynamic>()))
          .toList(),
      offers: (json['offers'] as List<dynamic>?)
          ?.map((o) => OfferViewEntity.fromJson((o as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  /// The one derivative this viewer may fetch for feed/detail thumbnails:
  /// third parties on a high-tier case get ONLY the blur (decision 128).
  String get thumbVariant =>
      (access == ReportAccess.owner || access == ReportAccess.participant)
          ? 'thumb'
          : (tier == 'high' ? 'blur' : 'thumb');

  @override
  List<Object?> get props => [
        access, reportId, category, freeTag, subject, tier, status, position,
        detailFields, createdAt, resolvedAt, timeline, media, offers,
      ];
}
