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

/// The `rating` facet of an owner-view offer (RT2 — decisions 48/180/
/// 183/184): `ratable` is computed server-side (resolved, not hidden, the
/// helper has an account, not yet rated) — the app trusts it as-is and
/// NEVER recomputes the rule. `score` is null until a rating exists.
class OfferRatingEntity extends Equatable {
  const OfferRatingEntity({this.score, required this.ratable});

  final int? score;
  final bool ratable;

  factory OfferRatingEntity.fromJson(Map<String, dynamic> json) => OfferRatingEntity(
        score: json['score'] as int?,
        ratable: json['ratable'] as bool,
      );

  @override
  List<Object?> get props => [score, ratable];
}

/// Offer row as the OWNER sees it — identity only when the helper chose
/// it and the tier allows (6/40/60); no timestamp on high tier (41).
class OfferViewEntity extends Equatable {
  const OfferViewEntity({
    required this.helpOfferId,
    required this.helpType,
    this.helperDisplayName,
    this.createdAt,
    this.rating,
  });

  final int helpOfferId;
  final String helpType;
  final String? helperDisplayName;
  final String? createdAt;

  /// Absent on every non-owner view (185); the owner view always sends it,
  /// but parsing stays defensive rather than assuming it.
  final OfferRatingEntity? rating;

  factory OfferViewEntity.fromJson(Map<String, dynamic> json) => OfferViewEntity(
        helpOfferId: json['helpOfferId'] as int,
        helpType: json['helpType'] as String,
        helperDisplayName: json['helperDisplayName'] as String?,
        createdAt: json['createdAt'] as String?,
        rating: json['rating'] == null
            ? null
            : OfferRatingEntity.fromJson((json['rating'] as Map).cast<String, dynamic>()),
      );

  @override
  List<Object?> get props => [helpOfferId, helpType, helperDisplayName, createdAt, rating];
}

/// The `chat` facet of an owner/participant view (C2, decision 169): the
/// SERVER says whether this viewer can chat — the owner gets
/// `{threads, unread}`, a helper participant `{threadId, unread}` with
/// `threadId` null before their first message (173). Absent → no chat.
class ReportChatFacetEntity extends Equatable {
  const ReportChatFacetEntity({this.threads, this.threadId, required this.unread});

  /// Owner only: how many helpers opened a thread.
  final int? threads;

  /// Helper participant only: their own thread, null until they write.
  final int? threadId;
  final int unread;

  /// The owner's shape carries `threads`; the helper's carries `threadId`
  /// (possibly null), never `threads`.
  bool get isOwner => threads != null;

  factory ReportChatFacetEntity.fromJson(Map<String, dynamic> json) => ReportChatFacetEntity(
        threads: json['threads'] as int?,
        threadId: json['threadId'] as int?,
        unread: json['unread'] as int? ?? 0,
      );

  @override
  List<Object?> get props => [threads, threadId, unread];
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
    this.hidden = false,
    this.chat,
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

  /// Hidden by panel moderation (B2, decision 167): the case is gone from
  /// the feed and from third parties; the OWNER and PARTICIPANTS still get
  /// it, with this mark only — never the reason (that is audit material).
  /// Absent from the API → `false`.
  final bool hidden;

  /// Served only to the owner and to a helper participant with an account
  /// (decision 169); null means this viewer has no chat on this case.
  final ReportChatFacetEntity? chat;

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
      hidden: json['hidden'] as bool? ?? false,
      chat: json['chat'] == null
          ? null
          : ReportChatFacetEntity.fromJson((json['chat'] as Map).cast<String, dynamic>()),
    );
  }

  /// Patches only the offers list — used after a rating settles so the one
  /// affected row updates without a network round trip (RT2, decisions
  /// 181/183); every other field is carried over unchanged.
  ReportViewEntity copyWithOffers(List<OfferViewEntity> offers) => ReportViewEntity(
        access: access,
        reportId: reportId,
        category: category,
        freeTag: freeTag,
        subject: subject,
        tier: tier,
        status: status,
        position: position,
        detailFields: detailFields,
        createdAt: createdAt,
        resolvedAt: resolvedAt,
        timeline: timeline,
        media: media,
        offers: offers,
        hidden: hidden,
        chat: chat,
      );

  /// The one derivative this viewer may fetch for feed/detail thumbnails:
  /// third parties on a high-tier case get ONLY the blur (decision 128).
  String get thumbVariant =>
      (access == ReportAccess.owner || access == ReportAccess.participant)
          ? 'thumb'
          : (tier == 'high' ? 'blur' : 'thumb');

  @override
  List<Object?> get props => [
        access, reportId, category, freeTag, subject, tier, status, position,
        detailFields, createdAt, resolvedAt, timeline, media, offers, hidden, chat,
      ];
}
