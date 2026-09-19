import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/help_offer_entity.dart';
import '../../domain/usecase/submit_help_offer_usecase.dart';
import '../../domain/usecase/update_help_offer_types_usecase.dart';

sealed class HelpOfferEvent extends Equatable {
  const HelpOfferEvent();

  @override
  List<Object?> get props => [];
}

/// A NEW offer on [reportId] (decisions 10/20/34/35).
class HelpOfferStarted extends HelpOfferEvent {
  const HelpOfferStarted(this.reportId);

  final int reportId;

  @override
  List<Object?> get props => [reportId];
}

/// Editing the fronts of this helper's OWN existing offer (decision 211):
/// the form opens with [current] checked and submit replaces the set.
class HelpOfferEditStarted extends HelpOfferEvent {
  const HelpOfferEditStarted({required this.helpOfferId, required this.current});

  final int helpOfferId;
  final Set<HelpType> current;

  @override
  List<Object?> get props => [helpOfferId, current];
}

/// One checkbox flipped — a real multi-select (decision 208): toggling
/// adds or removes that front, never replaces the others.
class HelpOfferTypeToggled extends HelpOfferEvent {
  const HelpOfferTypeToggled(this.helpType);

  final HelpType helpType;

  @override
  List<Object?> get props => [helpType];
}

class HelpOfferSubmitPressed extends HelpOfferEvent {
  const HelpOfferSubmitPressed({required this.anonymous});

  final bool anonymous;

  @override
  List<Object?> get props => [anonymous];
}

sealed class HelpOfferState extends Equatable {
  const HelpOfferState();

  @override
  List<Object?> get props => [];
}

class HelpOfferReady extends HelpOfferState {
  const HelpOfferReady({this.selected = const {}, this.failure});

  /// The fronts checked so far — submit needs at least one (208).
  final Set<HelpType> selected;

  /// Last submission failure, kept so the form can show it and retry.
  final Failure? failure;

  @override
  List<Object?> get props => [selected, failure];
}

/// Self-dealing (decision 20, spec scenario): the viewer reported this
/// case from this device — the form renders DISABLED, not just rejected.
class HelpOfferBlockedSelfDealing extends HelpOfferState {
  const HelpOfferBlockedSelfDealing();
}

class HelpOfferSubmitting extends HelpOfferState {
  const HelpOfferSubmitting(this.selected);

  final Set<HelpType> selected;

  @override
  List<Object?> get props => [selected];
}

class HelpOfferSuccess extends HelpOfferState {
  const HelpOfferSuccess(this.helpOfferId);

  final int helpOfferId;

  @override
  List<Object?> get props => [helpOfferId];
}

/// The set of fronts of an existing offer was replaced (decision 211).
class HelpOfferTypesUpdated extends HelpOfferState {
  const HelpOfferTypesUpdated(this.helpTypes);

  final Set<HelpType> helpTypes;

  @override
  List<Object?> get props => [helpTypes];
}

/// Offer-help flow (spec task 10, decisions 6/10/20/34/35) and, since
/// HT2 (211), the "change my fronts" edit of an existing offer — same
/// checkboxes, same submit, different verb on the wire.
class HelpOfferBloc extends Bloc<HelpOfferEvent, HelpOfferState> {
  HelpOfferBloc(
    this._submitHelpOffer,
    this._updateHelpOfferTypes, {
    required OwnsReport ownsReport,
  })  : _ownsReport = ownsReport,
        super(const HelpOfferReady()) {
    on<HelpOfferStarted>(_onStarted);
    on<HelpOfferEditStarted>(_onEditStarted);
    on<HelpOfferTypeToggled>(_onTypeToggled);
    on<HelpOfferSubmitPressed>(_onSubmitPressed);
  }

  final SubmitHelpOfferUsecase _submitHelpOffer;
  final UpdateHelpOfferTypesUsecase _updateHelpOfferTypes;
  final OwnsReport _ownsReport;
  int? _reportId;

  /// Non-null while editing an existing offer's fronts (211).
  int? _editingOfferId;

  Future<void> _onStarted(HelpOfferStarted event, Emitter<HelpOfferState> emit) async {
    _reportId = event.reportId;
    _editingOfferId = null;
    // Blocked WITHOUT touching the usecase (spec scenario) — this also
    // covers a crafted deep link straight to the form.
    if (await _ownsReport(event.reportId)) {
      emit(const HelpOfferBlockedSelfDealing());
    }
  }

  void _onEditStarted(HelpOfferEditStarted event, Emitter<HelpOfferState> emit) {
    // No self-dealing check here: the server only serves `myOffer` to a
    // participant, and it never makes the owner a participant.
    _editingOfferId = event.helpOfferId;
    emit(HelpOfferReady(selected: event.current));
  }

  void _onTypeToggled(HelpOfferTypeToggled event, Emitter<HelpOfferState> emit) {
    final current = state;
    if (current is! HelpOfferReady) return; // blocked, submitting, done
    final next = Set<HelpType>.of(current.selected);
    if (!next.remove(event.helpType)) next.add(event.helpType);
    emit(HelpOfferReady(selected: next));
  }

  Future<void> _onSubmitPressed(
    HelpOfferSubmitPressed event,
    Emitter<HelpOfferState> emit,
  ) async {
    final current = state;
    if (current is! HelpOfferReady || current.selected.isEmpty) return;

    final selected = current.selected;
    final editingOfferId = _editingOfferId;
    if (editingOfferId != null) {
      emit(HelpOfferSubmitting(selected));
      final result = await _updateHelpOfferTypes(editingOfferId, selected);
      if (emit.isDone) return;
      result.fold(
        (failure) => emit(HelpOfferReady(selected: selected, failure: failure)),
        (stored) => emit(HelpOfferTypesUpdated(stored)),
      );
      return;
    }

    final reportId = _reportId;
    if (reportId == null) return;
    emit(HelpOfferSubmitting(selected));
    final result = await _submitHelpOffer(HelpOfferEntity(
      reportId: reportId,
      helpTypes: selected,
      anonymous: event.anonymous,
    ));
    if (emit.isDone) return;
    result.fold(
      (failure) => failure.code == 'SELF_DEALING'
          ? emit(const HelpOfferBlockedSelfDealing())
          : emit(HelpOfferReady(selected: selected, failure: failure)),
      (helpOfferId) => emit(HelpOfferSuccess(helpOfferId)),
    );
  }
}
