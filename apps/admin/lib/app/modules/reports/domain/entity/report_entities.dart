import 'package:equatable/equatable.dart';

/// Search filters of `GET /api/reports` (B1 contract). Every field is
/// optional; [toQueryParameters] emits only what is set, under the exact
/// query names the API validates (decision 83 — a bad value is a 422 with
/// field codes, rendered by the screen).
class ReportFiltersEntity extends Equatable {
  const ReportFiltersEntity({
    this.id,
    this.status,
    this.category,
    this.subject,
    this.tier,
    this.frozen,
    this.hasMedia,
    this.hidden,
    this.reviewed,
    this.from,
    this.to,
  });

  final int? id;
  final String? status;
  final String? category;
  final String? subject;
  final String? tier;
  final bool? frozen;
  final bool? hasMedia;

  /// Moderation flag (B2, decision 162): `hidden=true|false`.
  final bool? hidden;

  /// Review mark (B3, decision 161): `reviewed=true|false`.
  final bool? reviewed;

  /// `YYYY-MM-DD` (or ISO date-time) on `created_at`.
  final String? from;
  final String? to;

  Map<String, String> toQueryParameters() => {
        if (id != null) 'id': '$id',
        if (status != null) 'status': status!,
        if (category != null) 'category': category!,
        if (subject != null) 'subject': subject!,
        if (tier != null) 'tier': tier!,
        if (frozen != null) 'frozen': '$frozen',
        if (hasMedia != null) 'hasMedia': '$hasMedia',
        if (hidden != null) 'hidden': '$hidden',
        if (reviewed != null) 'reviewed': '$reviewed',
        if (from != null) 'from': from!,
        if (to != null) 'to': to!,
      };

  @override
  List<Object?> get props =>
      [id, status, category, subject, tier, frozen, hasMedia, hidden, reviewed, from, to];
}

/// A DEGRADED grid point (decision 135/159) — never the exact position.
class ReportPositionEntity extends Equatable {
  const ReportPositionEntity({required this.lat, required this.lng, this.precisionMeters});

  final double lat;
  final double lng;

  /// Grid size in metres (`GRID_BY_TIER`), present on the detail only.
  final int? precisionMeters;

  factory ReportPositionEntity.fromJson(Map<String, dynamic> json) => ReportPositionEntity(
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        precisionMeters: (json['precisionMeters'] as num?)?.toInt(),
      );

  @override
  List<Object?> get props => [lat, lng, precisionMeters];
}

/// One row of the paginated search (`ReportListItem`).
class ReportListItemEntity extends Equatable {
  const ReportListItemEntity({
    required this.reportId,
    required this.category,
    required this.freeTag,
    required this.subject,
    required this.tier,
    required this.status,
    required this.anonymous,
    required this.frozen,
    required this.purged,
    this.hidden = false,
    this.reviewed = false,
    required this.mediaCount,
    required this.position,
    required this.createdAt,
    required this.resolvedAt,
  });

  final int reportId;
  final String? category;
  final String? freeTag;
  final String subject;
  final String tier;
  final String status;
  final bool anonymous;
  final bool frozen;

  /// Statistical skeleton (25/131): kept in the list, content gone.
  final bool purged;

  /// Hidden by moderation (162): gone from the feed and public reads,
  /// still listed here. `false` when the API does not send it.
  final bool hidden;

  /// A human marked the case reviewed (B3, decision 161) — it left the
  /// proactive queue. `false` when the API does not send it.
  final bool reviewed;
  final int mediaCount;
  final ReportPositionEntity? position;
  final String createdAt;
  final String? resolvedAt;

  factory ReportListItemEntity.fromJson(Map<String, dynamic> json) => ReportListItemEntity(
        reportId: (json['reportId'] as num).toInt(),
        category: json['category'] as String?,
        freeTag: json['freeTag'] as String?,
        subject: json['subject'] as String,
        tier: json['tier'] as String,
        status: json['status'] as String,
        anonymous: json['anonymous'] as bool,
        frozen: json['frozen'] as bool,
        purged: json['purged'] as bool,
        hidden: json['hidden'] as bool? ?? false,
        reviewed: json['reviewed'] as bool? ?? false,
        mediaCount: (json['mediaCount'] as num).toInt(),
        position: json['position'] == null
            ? null
            : ReportPositionEntity.fromJson((json['position'] as Map).cast<String, dynamic>()),
        createdAt: json['createdAt'] as String,
        resolvedAt: json['resolvedAt'] as String?,
      );

  @override
  List<Object?> get props => [
        reportId, category, freeTag, subject, tier, status, anonymous, frozen, purged,
        hidden, reviewed, mediaCount, position, createdAt, resolvedAt,
      ];
}

/// One row of the proactive moderation queue (B3, decision 161): the B1
/// `ReportListItem` shape (degraded position, no identity) plus the queue
/// fields the API resolves — the tier as [priority], whether living media
/// is attached, and whole hours since `created_at`. The ORDER is the
/// server's (tier → media → oldest); the screen never re-sorts.
class QueueItemEntity extends Equatable {
  const QueueItemEntity({
    required this.item,
    required this.priority,
    required this.hasMedia,
    required this.ageHours,
  });

  final ReportListItemEntity item;

  /// `high | medium | low`.
  final String priority;
  final bool hasMedia;
  final int ageHours;

  factory QueueItemEntity.fromJson(Map<String, dynamic> json) => QueueItemEntity(
        item: ReportListItemEntity.fromJson(json),
        priority: json['priority'] as String,
        hasMedia: json['hasMedia'] as bool,
        ageHours: (json['ageHours'] as num).toInt(),
      );

  @override
  List<Object?> get props => [item, priority, hasMedia, ageHours];
}

/// `GET /api/reports/queue` → `{ items, page, pageSize, total }`.
class QueuePageEntity extends Equatable {
  const QueuePageEntity({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<QueueItemEntity> items;
  final int page;
  final int pageSize;
  final int total;

  int get pageCount => total == 0 ? 1 : (total + pageSize - 1) ~/ pageSize;

  factory QueuePageEntity.fromJson(Map<String, dynamic> json) => QueuePageEntity(
        items: (json['items'] as List)
            .map((e) => QueueItemEntity.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        page: (json['page'] as num).toInt(),
        pageSize: (json['pageSize'] as num).toInt(),
        total: (json['total'] as num).toInt(),
      );

  @override
  List<Object?> get props => [items, page, pageSize, total];
}

/// `{ items, page, pageSize, total }`.
class ReportPageEntity extends Equatable {
  const ReportPageEntity({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<ReportListItemEntity> items;
  final int page;
  final int pageSize;
  final int total;

  int get pageCount => total == 0 ? 1 : (total + pageSize - 1) ~/ pageSize;

  factory ReportPageEntity.fromJson(Map<String, dynamic> json) => ReportPageEntity(
        items: (json['items'] as List)
            .map((e) => ReportListItemEntity.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        page: (json['page'] as num).toInt(),
        pageSize: (json['pageSize'] as num).toInt(),
        total: (json['total'] as num).toInt(),
      );

  @override
  List<Object?> get props => [items, page, pageSize, total];
}

/// An IDENTIFIED actor as the panel may see it (decision 160): opaque
/// account id + display name, never e-mail. Anonymous actors are `null`
/// wherever this type appears — the API never sends their identity.
class ReportActorEntity extends Equatable {
  const ReportActorEntity({required this.accountId, required this.displayName});

  final int accountId;
  final String displayName;

  factory ReportActorEntity.fromJson(Map<String, dynamic> json) => ReportActorEntity(
        accountId: (json['accountId'] as num).toInt(),
        displayName: json['displayName'] as String,
      );

  @override
  List<Object?> get props => [accountId, displayName];
}

class ReportTimelineEventEntity extends Equatable {
  const ReportTimelineEventEntity({
    required this.eventType,
    required this.payload,
    required this.createdAt,
  });

  final String eventType;
  final Map<String, dynamic>? payload;
  final String createdAt;

  factory ReportTimelineEventEntity.fromJson(Map<String, dynamic> json) =>
      ReportTimelineEventEntity(
        eventType: json['eventType'] as String,
        payload: (json['payload'] as Map?)?.cast<String, dynamic>(),
        createdAt: json['createdAt'] as String,
      );

  @override
  List<Object?> get props => [eventType, payload, createdAt];
}

/// Attached media as `tb_media` knows it — the image itself stays behind
/// `/api/media` under `media_evidence` (130/165).
class ReportMediaEntity extends Equatable {
  const ReportMediaEntity({
    required this.publicId,
    required this.mime,
    required this.width,
    required this.height,
    required this.status,
    this.blockedReasonCode,
    this.blockedNote,
    this.blockedAt,
  });

  final String publicId;
  final String mime;
  final int? width;
  final int? height;

  /// pending / available / blocked / deleted.
  final String status;

  /// Set while `status == 'blocked'` (B2, decisions 162/163): the catalog
  /// code, the optional note and when. The panel keeps listing blocked
  /// media — a hold preserves evidence (M3).
  final String? blockedReasonCode;
  final String? blockedNote;
  final String? blockedAt;

  factory ReportMediaEntity.fromJson(Map<String, dynamic> json) => ReportMediaEntity(
        publicId: json['publicId'] as String,
        mime: json['mime'] as String,
        width: (json['width'] as num?)?.toInt(),
        height: (json['height'] as num?)?.toInt(),
        status: json['status'] as String,
        blockedReasonCode: json['blockedReasonCode'] as String?,
        blockedNote: json['blockedNote'] as String?,
        blockedAt: json['blockedAt'] as String?,
      );

  @override
  List<Object?> get props =>
      [publicId, mime, width, height, status, blockedReasonCode, blockedNote, blockedAt];
}

class ReportOfferEntity extends Equatable {
  const ReportOfferEntity({
    required this.helpOfferId,
    required this.helpType,
    required this.anonymous,
    required this.helper,
    required this.createdAt,
  });

  final int helpOfferId;
  final String helpType;
  final bool anonymous;

  /// `null` for an anonymous offer (decision 160 applied to helpers).
  final ReportActorEntity? helper;
  final String createdAt;

  factory ReportOfferEntity.fromJson(Map<String, dynamic> json) => ReportOfferEntity(
        helpOfferId: (json['helpOfferId'] as num).toInt(),
        helpType: json['helpType'] as String,
        anonymous: json['anonymous'] as bool,
        helper: json['helper'] == null
            ? null
            : ReportActorEntity.fromJson((json['helper'] as Map).cast<String, dynamic>()),
        createdAt: json['createdAt'] as String,
      );

  @override
  List<Object?> get props => [helpOfferId, helpType, anonymous, helper, createdAt];
}

/// `GET /api/reports/:id` (`ReportPanelDetail`). Opening it is AUDITED
/// server-side (decision 166). A purged row arrives as the skeleton:
/// taxonomy, status, dates, `purged: true`, everything else null/empty.
class ReportPanelDetailEntity extends Equatable {
  const ReportPanelDetailEntity({
    required this.reportId,
    required this.category,
    required this.freeTag,
    required this.subject,
    required this.tier,
    required this.status,
    required this.anonymous,
    required this.frozen,
    required this.frozenReason,
    required this.frozenAt,
    required this.purged,
    required this.createdAt,
    required this.resolvedAt,
    required this.expiresAt,
    this.hidden = false,
    this.hiddenReasonCode,
    this.hiddenNote,
    this.hiddenAt,
    this.hiddenBy,
    this.reviewedAt,
    this.reviewedBy,
    required this.reporter,
    required this.position,
    required this.detailFields,
    required this.timeline,
    required this.media,
    required this.offers,
  });

  final int reportId;
  final String? category;
  final String? freeTag;
  final String subject;
  final String tier;
  final String status;
  final bool anonymous;
  final bool frozen;
  final String? frozenReason;
  final String? frozenAt;
  final bool purged;
  final String createdAt;
  final String? resolvedAt;
  final String? expiresAt;

  /// Moderation (B2, decisions 162/163/167): hidden from the feed and
  /// from third-party reads, retention untouched. The reason lives HERE
  /// and in the audit — never in the owner's view.
  final bool hidden;
  final String? hiddenReasonCode;
  final String? hiddenNote;
  final String? hiddenAt;
  final int? hiddenBy;

  /// Review mark (B3, decision 161): when ONE human with `reports` UPDATE
  /// marked the case reviewed, and who. Not a moderation act — no reason.
  /// Both `null` while the case still sits in the queue.
  final String? reviewedAt;
  final int? reviewedBy;

  /// `null` when anonymous (decision 160).
  final ReportActorEntity? reporter;

  /// Degraded grid with its precision (159); `null` when purged.
  final ReportPositionEntity? position;
  final Map<String, dynamic>? detailFields;
  final List<ReportTimelineEventEntity> timeline;
  final List<ReportMediaEntity> media;
  final List<ReportOfferEntity> offers;

  factory ReportPanelDetailEntity.fromJson(Map<String, dynamic> json) => ReportPanelDetailEntity(
        reportId: (json['reportId'] as num).toInt(),
        category: json['category'] as String?,
        freeTag: json['freeTag'] as String?,
        subject: json['subject'] as String,
        tier: json['tier'] as String,
        status: json['status'] as String,
        anonymous: json['anonymous'] as bool,
        frozen: json['frozen'] as bool,
        frozenReason: json['frozenReason'] as String?,
        frozenAt: json['frozenAt'] as String?,
        purged: json['purged'] as bool,
        createdAt: json['createdAt'] as String,
        resolvedAt: json['resolvedAt'] as String?,
        expiresAt: json['expiresAt'] as String?,
        hidden: json['hidden'] as bool? ?? false,
        hiddenReasonCode: json['hiddenReasonCode'] as String?,
        hiddenNote: json['hiddenNote'] as String?,
        hiddenAt: json['hiddenAt'] as String?,
        hiddenBy: (json['hiddenBy'] as num?)?.toInt(),
        reviewedAt: json['reviewedAt'] as String?,
        reviewedBy: (json['reviewedBy'] as num?)?.toInt(),
        reporter: json['reporter'] == null
            ? null
            : ReportActorEntity.fromJson((json['reporter'] as Map).cast<String, dynamic>()),
        position: json['position'] == null
            ? null
            : ReportPositionEntity.fromJson((json['position'] as Map).cast<String, dynamic>()),
        detailFields: (json['detailFields'] as Map?)?.cast<String, dynamic>(),
        timeline: ((json['timeline'] as List?) ?? const [])
            .map((e) => ReportTimelineEventEntity.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        media: ((json['media'] as List?) ?? const [])
            .map((e) => ReportMediaEntity.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        offers: ((json['offers'] as List?) ?? const [])
            .map((e) => ReportOfferEntity.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );

  @override
  List<Object?> get props => [
        reportId, category, freeTag, subject, tier, status, anonymous, frozen, frozenReason,
        frozenAt, purged, createdAt, resolvedAt, expiresAt, hidden, hiddenReasonCode,
        hiddenNote, hiddenAt, hiddenBy, reviewedAt, reviewedBy, reporter, position,
        detailFields, timeline, media, offers,
      ];
}

/// `GET /api/reports/:id/position` — the ONE exact read, behind the
/// `report_exact_position` grant and audited per call (decision 159).
class ReportExactPositionEntity extends Equatable {
  const ReportExactPositionEntity({required this.reportId, required this.lat, required this.lng});

  final int reportId;
  final double lat;
  final double lng;

  factory ReportExactPositionEntity.fromJson(Map<String, dynamic> json) =>
      ReportExactPositionEntity(
        reportId: (json['reportId'] as num).toInt(),
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
      );

  @override
  List<Object?> get props => [reportId, lat, lng];
}

/// Step 1 of the dual-control unfreeze (141d) — same shape the case-freeze
/// module reads; duplicated because modules never import each other.
class ReportPendingUnfreezeEntity extends Equatable {
  const ReportPendingUnfreezeEntity({
    required this.reason,
    required this.requestedBy,
    required this.requestedAt,
  });

  final String reason;
  final int requestedBy;
  final String requestedAt;

  factory ReportPendingUnfreezeEntity.fromJson(Map<String, dynamic> json) =>
      ReportPendingUnfreezeEntity(
        reason: json['reason'] as String,
        requestedBy: (json['requestedBy'] as num).toInt(),
        requestedAt: json['requestedAt'] as String,
      );

  @override
  List<Object?> get props => [reason, requestedBy, requestedAt];
}

/// `GET /api/case-freeze/:id`, embedded in the detail (decision 165).
class ReportFreezeStateEntity extends Equatable {
  const ReportFreezeStateEntity({
    required this.reportId,
    required this.status,
    required this.frozen,
    this.frozenReason,
    this.frozenAt,
    this.pendingUnfreeze,
  });

  final int reportId;
  final String status;
  final bool frozen;
  final String? frozenReason;
  final String? frozenAt;
  final ReportPendingUnfreezeEntity? pendingUnfreeze;

  factory ReportFreezeStateEntity.fromJson(Map<String, dynamic> json) => ReportFreezeStateEntity(
        reportId: (json['reportId'] as num).toInt(),
        status: json['status'] as String,
        frozen: json['frozen'] as bool,
        frozenReason: json['frozenReason'] as String?,
        frozenAt: json['frozenAt'] as String?,
        pendingUnfreeze: json['pendingUnfreeze'] == null
            ? null
            : ReportPendingUnfreezeEntity.fromJson(
                (json['pendingUnfreeze'] as Map).cast<String, dynamic>()),
      );

  @override
  List<Object?> get props => [reportId, status, frozen, frozenReason, frozenAt, pendingUnfreeze];
}
