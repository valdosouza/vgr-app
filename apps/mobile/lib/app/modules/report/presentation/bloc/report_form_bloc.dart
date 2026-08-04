import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entity/photo_draft.dart';
import '../../domain/entity/report_input.dart';
import '../../domain/entity/report_taxonomy.dart';
import '../../domain/gateway/location_gateway.dart';
import '../../domain/gateway/photo_gateway.dart';
import '../../domain/repository/report_repository.dart';
import '../../domain/usecase/submit_report_usecase.dart';
import 'report_form_event.dart';
import 'report_form_state.dart';

class ReportFormBloc extends Bloc<ReportFormEvent, ReportFormState> {
  ReportFormBloc(
    this._submitReport,
    this._repository,
    this._locationGateway,
    this._photoGateway, {
    String Function()? clientKeyFactory,
  })  : _newClientKey = clientKeyFactory ?? (() => const Uuid().v4()),
        super(const ReportFormState()) {
    // One key per DRAFT (decision 137): every retry of this draft — user
    // tap or queue replay — is the same report to the API.
    _clientKey = _newClientKey();

    on<ReportFormStarted>(_onStarted);
    on<ReportPositionRetryRequested>(_onPositionRetry);
    on<ReportPhotoPickRequested>(_onPhotoPick);
    on<ReportPhotoRemoved>(_onPhotoRemoved);
    on<ReportPhotoKeepOriginalChanged>(_onPhotoKeepChanged);
    on<ReportSubmitPressed>(_onSubmitPressed);
    on<ReportFormReset>(_onReset);
  }

  final SubmitReportUsecase _submitReport;
  final ReportRepository _repository;
  final LocationGateway _locationGateway;
  final PhotoGateway _photoGateway;
  final String Function() _newClientKey;

  late String _clientKey;

  Future<void> _onStarted(ReportFormStarted event, Emitter<ReportFormState> emit) async {
    await Future.wait([_loadForms(emit), _locate(emit)]);
  }

  Future<void> _loadForms(Emitter<ReportFormState> emit) async {
    final result = await _repository.getCategoryForms();
    if (emit.isDone) return;
    result.fold(
      (failure) => emit(state.copyWith(formsStatus: FormsStatus.failed)),
      (forms) => emit(state.copyWith(
        formsStatus: FormsStatus.ready,
        forms: {for (final f in forms) f.category: f.fields},
      )),
    );
  }

  Future<void> _locate(Emitter<ReportFormState> emit) async {
    final result = await _locationGateway.currentPosition();
    if (emit.isDone) return;
    result.fold(
      (failure) => emit(state.copyWith(
        positionStatus: PositionStatus.failed,
        positionFailure: failure,
      )),
      (point) => emit(state.copyWith(
        positionStatus: PositionStatus.ready,
        position: point,
      )),
    );
  }

  Future<void> _onPositionRetry(
    ReportPositionRetryRequested event,
    Emitter<ReportFormState> emit,
  ) async {
    emit(state.copyWith(positionStatus: PositionStatus.locating));
    await _locate(emit);
  }

  Future<void> _onPhotoPick(
    ReportPhotoPickRequested event,
    Emitter<ReportFormState> emit,
  ) async {
    if (state.photos.length >= maxPhotosPerReport) return; // decision 129
    final path = event.fromCamera
        ? await _photoGateway.pickFromCamera()
        : await _photoGateway.pickFromGallery();
    if (path == null) return;
    emit(state.copyWith(photos: [...state.photos, PhotoDraft(path: path)]));
  }

  void _onPhotoRemoved(ReportPhotoRemoved event, Emitter<ReportFormState> emit) {
    if (event.index < 0 || event.index >= state.photos.length) return;
    final photos = [...state.photos]..removeAt(event.index);
    emit(state.copyWith(photos: photos));
  }

  void _onPhotoKeepChanged(
    ReportPhotoKeepOriginalChanged event,
    Emitter<ReportFormState> emit,
  ) {
    if (event.index < 0 || event.index >= state.photos.length) return;
    final photos = [...state.photos];
    photos[event.index] = PhotoDraft(
      path: photos[event.index].path,
      keepOriginal: event.keep,
      // The version of the text the reporter SAW (decisions 86/130).
      exifWarningVersion: event.keep ? exifWarningVersion : null,
    );
    emit(state.copyWith(photos: photos));
  }

  Future<void> _onSubmitPressed(
    ReportSubmitPressed event,
    Emitter<ReportFormState> emit,
  ) async {
    if (!state.canSubmit || state.position == null) return;

    final ReportInput input;
    try {
      input = ReportInput(
        clientKey: _clientKey,
        category: event.category,
        freeTag: event.freeTag,
        subject: event.subject,
        detailFields: event.detailFields,
        lat: state.position!.lat,
        lng: state.position!.lng,
        anonymous: event.anonymous,
        photos: state.photos,
      );
    } on ArgumentError {
      // The page's structure makes this unreachable; guard anyway.
      return;
    }

    emit(state.copyWith(submitStatus: SubmitStatus.submitting));
    final result = await _submitReport(input);
    result.fold(
      (failure) => emit(state.copyWith(submitStatus: SubmitStatus.failed, failure: failure)),
      (outcome) => emit(state.copyWith(
        submitStatus:
            outcome.queued ? SubmitStatus.queuedOffline : SubmitStatus.submittedOnline,
        reportId: outcome.reportId,
      )),
    );
  }

  void _onReset(ReportFormReset event, Emitter<ReportFormState> emit) {
    _clientKey = _newClientKey();
    emit(ReportFormState(
      // Catalog and position survive the reset — only the draft dies.
      formsStatus: state.formsStatus,
      forms: state.forms,
      positionStatus: state.positionStatus,
      position: state.position,
    ));
  }
}
