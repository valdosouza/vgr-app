import 'package:equatable/equatable.dart';

import 'photo_draft.dart';

/// Submission draft — the app-side mirror of the `POST /app-reports` body
/// (amendment MA1: two mandatory axes, decision 140; category XOR freeTag,
/// decision 9). `clientKey` is generated ONCE per draft and survives in
/// the offline queue, so every retry is the same report to the API
/// (decision 137).
class ReportInput extends Equatable {
  ReportInput({
    required this.clientKey,
    this.category,
    this.freeTag,
    required this.subject,
    this.detailFields = const {},
    required this.lat,
    required this.lng,
    required this.anonymous,
    this.photos = const [],
  }) {
    final hasCategory = category != null;
    final hasFreeTag = freeTag != null && freeTag!.trim().isNotEmpty;
    if (hasCategory == hasFreeTag) {
      throw ArgumentError('Provide exactly one of category or freeTag');
    }
  }

  final String clientKey;
  final String? category;
  final String? freeTag;
  final String subject;
  final Map<String, dynamic> detailFields;
  final double lat;
  final double lng;
  final bool anonymous;
  final List<PhotoDraft> photos;

  /// The `POST /app-reports` body — photos ride separately (`/app-media`
  /// then attach; decision 123: the report never waits for an image).
  Map<String, dynamic> toSubmitBody() => {
        'clientKey': clientKey,
        if (category != null) 'category': category,
        if (category == null) 'freeTag': freeTag!.trim(),
        'subject': subject,
        if (detailFields.isNotEmpty) 'detailFields': detailFields,
        'position': {'lat': lat, 'lng': lng},
        'anonymous': anonymous,
      };

  /// Full persistence shape for the offline queue.
  Map<String, dynamic> toJson() => {
        'clientKey': clientKey,
        'category': category,
        'freeTag': freeTag,
        'subject': subject,
        'detailFields': detailFields,
        'lat': lat,
        'lng': lng,
        'anonymous': anonymous,
        'photos': photos.map((p) => p.toJson()).toList(),
      };

  factory ReportInput.fromJson(Map<String, dynamic> json) => ReportInput(
        clientKey: json['clientKey'] as String,
        category: json['category'] as String?,
        freeTag: json['freeTag'] as String?,
        subject: json['subject'] as String,
        detailFields:
            (json['detailFields'] as Map<String, dynamic>?) ?? const {},
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        anonymous: json['anonymous'] as bool,
        photos: (json['photos'] as List<dynamic>? ?? const [])
            .map((p) => PhotoDraft.fromJson((p as Map).cast<String, dynamic>()))
            .toList(),
      );

  @override
  List<Object?> get props =>
      [clientKey, category, freeTag, subject, detailFields, lat, lng, anonymous, photos];
}

/// What submitting produced: an accepted report id (online) or a queued
/// draft (decision 28 — the queued state is a SUCCESS, not an error).
class SubmitOutcome extends Equatable {
  const SubmitOutcome.online(int this.reportId) : queued = false;
  const SubmitOutcome.queued()
      : reportId = null,
        queued = true;

  final int? reportId;
  final bool queued;

  @override
  List<Object?> get props => [reportId, queued];
}
