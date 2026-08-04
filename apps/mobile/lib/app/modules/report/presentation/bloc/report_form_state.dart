import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entity/category_form_schema_entity.dart';
import '../../domain/entity/photo_draft.dart';
import '../../domain/gateway/location_gateway.dart';

enum FormsStatus { loading, ready, failed }

enum PositionStatus { locating, ready, failed }

enum SubmitStatus { idle, submitting, submittedOnline, queuedOffline, failed }

class ReportFormState extends Equatable {
  const ReportFormState({
    this.formsStatus = FormsStatus.loading,
    this.forms = const {},
    this.positionStatus = PositionStatus.locating,
    this.position,
    this.positionFailure,
    this.photos = const [],
    this.submitStatus = SubmitStatus.idle,
    this.reportId,
    this.failure,
  });

  final FormsStatus formsStatus;

  /// category → detail fields (decision 47), rendered dynamically.
  final Map<String, List<CategoryFormField>> forms;

  final PositionStatus positionStatus;
  final GeoPoint? position;
  final Failure? positionFailure;

  final List<PhotoDraft> photos;

  final SubmitStatus submitStatus;
  final int? reportId;
  final Failure? failure;

  bool get canSubmit =>
      positionStatus == PositionStatus.ready && submitStatus != SubmitStatus.submitting;

  ReportFormState copyWith({
    FormsStatus? formsStatus,
    Map<String, List<CategoryFormField>>? forms,
    PositionStatus? positionStatus,
    GeoPoint? position,
    Failure? positionFailure,
    List<PhotoDraft>? photos,
    SubmitStatus? submitStatus,
    int? reportId,
    Failure? failure,
  }) =>
      ReportFormState(
        formsStatus: formsStatus ?? this.formsStatus,
        forms: forms ?? this.forms,
        positionStatus: positionStatus ?? this.positionStatus,
        position: position ?? this.position,
        positionFailure: positionFailure ?? this.positionFailure,
        photos: photos ?? this.photos,
        submitStatus: submitStatus ?? this.submitStatus,
        reportId: reportId ?? this.reportId,
        failure: failure ?? this.failure,
      );

  @override
  List<Object?> get props => [
        formsStatus,
        forms,
        positionStatus,
        position,
        positionFailure,
        photos,
        submitStatus,
        reportId,
        failure,
      ];
}
