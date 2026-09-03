import 'dart:convert';

import 'package:equatable/equatable.dart';

/// Filters of `GET /api/admin-audit` (B5 contract). Everything optional;
/// [toQueryParameters] emits only what is set, under the names the API
/// validates (decision 83 — a bad value is a 422 with field codes,
/// rendered by the screen).
class AuditFiltersEntity extends Equatable {
  const AuditFiltersEntity({
    this.actorId,
    this.action,
    this.entity,
    this.entityId,
    this.from,
    this.to,
  });

  /// A PANEL user id (`tb_user`) — the trail never references app accounts.
  final int? actorId;

  /// One of the `AuditAction` union: create · update · delete · grant ·
  /// state_change · read.
  final String? action;
  final String? entity;
  final String? entityId;

  /// `YYYY-MM-DD` on `created_at`, same date-only semantics as B1.
  final String? from;
  final String? to;

  Map<String, String> toQueryParameters() => {
        if (actorId != null) 'actorId': '$actorId',
        if (action != null) 'action': action!,
        if (entity != null) 'entity': entity!,
        if (entityId != null) 'entityId': entityId!,
        if (from != null) 'from': from!,
        if (to != null) 'to': to!,
      };

  @override
  List<Object?> get props => [actorId, action, entity, entityId, from, to];
}

/// One row of the paginated trail (`AuditListItem`): who / what / when.
/// Deliberately has NO `ip` field — the operator IP is personal data and
/// the API serves it only on the detail of one entry ([AuditEntryEntity]).
class AuditListItemEntity extends Equatable {
  const AuditListItemEntity({
    required this.id,
    required this.actorId,
    required this.actorName,
    required this.action,
    required this.entity,
    required this.entityId,
    required this.summary,
    required this.createdAt,
  });

  final int id;
  final int actorId;

  /// `tb_user.name` via LEFT JOIN — `null` when the panel user is gone;
  /// the row and its [actorId] stay (the trail never loses its actor).
  final String? actorName;
  final String action;
  final String entity;
  final String? entityId;

  /// Served as stored (already secret-redacted at write time, decision
  /// 110): a parsed JSON value when parseable, else the raw string, else
  /// `null`. The panel only ever renders it as text / a key-value tree.
  final Object? summary;
  final String createdAt;

  factory AuditListItemEntity.fromJson(Map<String, dynamic> json) => AuditListItemEntity(
        id: (json['id'] as num).toInt(),
        actorId: (json['actorId'] as num).toInt(),
        actorName: json['actorName'] as String?,
        action: json['action'] as String,
        entity: json['entity'] as String,
        entityId: json['entityId'] as String?,
        summary: json['summary'],
        createdAt: json['createdAt'] as String,
      );

  /// One line for the list row: compact JSON for a structured summary,
  /// whitespace collapsed for text, cut at [max] with an ellipsis.
  String summaryPreview({int max = 80}) {
    final raw = switch (summary) {
      null => '',
      final String s => s,
      final Object o => jsonEncode(o),
    };
    final line = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (line.length <= max) return line;
    return '${line.substring(0, max - 1)}…';
  }

  @override
  List<Object?> get props => [id, actorId, actorName, action, entity, entityId, summary, createdAt];
}

/// `GET /api/admin-audit/:id` (`AuditEntry`) — the list row plus the
/// operator [ip], the ONE place it is served.
class AuditEntryEntity extends AuditListItemEntity {
  const AuditEntryEntity({
    required super.id,
    required super.actorId,
    required super.actorName,
    required super.action,
    required super.entity,
    required super.entityId,
    required super.summary,
    required super.createdAt,
    required this.ip,
  });

  final String? ip;

  factory AuditEntryEntity.fromJson(Map<String, dynamic> json) {
    final base = AuditListItemEntity.fromJson(json);
    return AuditEntryEntity(
      id: base.id,
      actorId: base.actorId,
      actorName: base.actorName,
      action: base.action,
      entity: base.entity,
      entityId: base.entityId,
      summary: base.summary,
      createdAt: base.createdAt,
      ip: json['ip'] as String?,
    );
  }

  @override
  List<Object?> get props => [...super.props, ip];
}

/// `{ items, page, pageSize, total }`.
class AuditPageEntity extends Equatable {
  const AuditPageEntity({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<AuditListItemEntity> items;
  final int page;
  final int pageSize;
  final int total;

  int get pageCount => total == 0 ? 1 : (total + pageSize - 1) ~/ pageSize;

  factory AuditPageEntity.fromJson(Map<String, dynamic> json) => AuditPageEntity(
        items: (json['items'] as List)
            .map((e) => AuditListItemEntity.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        page: (json['page'] as num).toInt(),
        pageSize: (json['pageSize'] as num).toInt(),
        total: (json['total'] as num).toInt(),
      );

  @override
  List<Object?> get props => [items, page, pageSize, total];
}

/// `GET /api/admin-audit/facets` — the DISTINCT actions and entities
/// present in the table, for the screen's dropdowns.
class AuditFacetsEntity extends Equatable {
  const AuditFacetsEntity({required this.actions, required this.entities});

  /// Dropdowns with nothing to offer — the list still works.
  static const empty = AuditFacetsEntity(actions: [], entities: []);

  final List<String> actions;
  final List<String> entities;

  factory AuditFacetsEntity.fromJson(Map<String, dynamic> json) => AuditFacetsEntity(
        actions: ((json['actions'] as List?) ?? const []).cast<String>(),
        entities: ((json['entities'] as List?) ?? const []).cast<String>(),
      );

  @override
  List<Object?> get props => [actions, entities];
}
