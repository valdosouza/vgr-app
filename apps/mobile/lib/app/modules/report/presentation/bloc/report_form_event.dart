import 'package:equatable/equatable.dart';

sealed class ReportFormEvent extends Equatable {
  const ReportFormEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the category-form catalog and the device position.
class ReportFormStarted extends ReportFormEvent {
  const ReportFormStarted();
}

class ReportPositionRetryRequested extends ReportFormEvent {
  const ReportPositionRetryRequested();
}

class ReportPhotoPickRequested extends ReportFormEvent {
  const ReportPhotoPickRequested({required this.fromCamera});

  final bool fromCamera;

  @override
  List<Object?> get props => [fromCamera];
}

class ReportPhotoRemoved extends ReportFormEvent {
  const ReportPhotoRemoved(this.index);

  final int index;

  @override
  List<Object?> get props => [index];
}

/// The page shows the EXIF warning dialog (decisions 130/139) BEFORE
/// dispatching keep=true — this event records an informed choice.
class ReportPhotoKeepOriginalChanged extends ReportFormEvent {
  const ReportPhotoKeepOriginalChanged(this.index, {required this.keep});

  final int index;
  final bool keep;

  @override
  List<Object?> get props => [index, keep];
}

class ReportSubmitPressed extends ReportFormEvent {
  const ReportSubmitPressed({
    this.category,
    this.freeTag,
    required this.subject,
    this.detailFields = const {},
    required this.anonymous,
  });

  final String? category;
  final String? freeTag;
  final String subject;
  final Map<String, dynamic> detailFields;
  final bool anonymous;

  @override
  List<Object?> get props => [category, freeTag, subject, detailFields, anonymous];
}

/// "New report" after a submission: fresh draft, fresh clientKey.
class ReportFormReset extends ReportFormEvent {
  const ReportFormReset();
}
