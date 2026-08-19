import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/help_offer_entity.dart';
import '../../domain/usecase/submit_help_offer_usecase.dart';

sealed class HelpOfferEvent extends Equatable {
  const HelpOfferEvent();

  @override
  List<Object?> get props => [];
}

class HelpOfferStarted extends HelpOfferEvent {
  const HelpOfferStarted(this.reportId);

  final int reportId;

  @override
  List<Object?> get props => [reportId];
}

class HelpOfferTypeSelected extends HelpOfferEvent {
  const HelpOfferTypeSelected(this.helpType);

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
  const HelpOfferReady({this.selected, this.failure});

  final HelpType? selected;

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

  final HelpType selected;

  @override
  List<Object?> get props => [selected];
}

class HelpOfferSuccess extends HelpOfferState {
  const HelpOfferSuccess(this.helpOfferId);

  final int helpOfferId;

  @override
  List<Object?> get props => [helpOfferId];
}

/// Offer-help flow (spec task 10, decisions 6/10/20/34/35).
class HelpOfferBloc extends Bloc<HelpOfferEvent, HelpOfferState> {
  HelpOfferBloc(this._submitHelpOffer, {required OwnsReport ownsReport})
      : _ownsReport = ownsReport,
        super(const HelpOfferReady()) {
    on<HelpOfferStarted>(_onStarted);
    on<HelpOfferTypeSelected>(_onTypeSelected);
    on<HelpOfferSubmitPressed>(_onSubmitPressed);
  }

  final SubmitHelpOfferUsecase _submitHelpOffer;
  final OwnsReport _ownsReport;
  int? _reportId;

  Future<void> _onStarted(HelpOfferStarted event, Emitter<HelpOfferState> emit) async {
    _reportId = event.reportId;
    // Blocked WITHOUT touching the usecase (spec scenario) — this also
    // covers a crafted deep link straight to the form.
    if (await _ownsReport(event.reportId)) {
      emit(const HelpOfferBlockedSelfDealing());
    }
  }

  void _onTypeSelected(HelpOfferTypeSelected event, Emitter<HelpOfferState> emit) {
    if (state is HelpOfferBlockedSelfDealing || state is HelpOfferSubmitting) return;
    emit(HelpOfferReady(selected: event.helpType));
  }

  Future<void> _onSubmitPressed(
    HelpOfferSubmitPressed event,
    Emitter<HelpOfferState> emit,
  ) async {
    final current = state;
    final reportId = _reportId;
    if (current is! HelpOfferReady || current.selected == null || reportId == null) {
      return;
    }

    final selected = current.selected!;
    emit(HelpOfferSubmitting(selected));
    final result = await _submitHelpOffer(HelpOfferEntity(
      reportId: reportId,
      helpType: selected,
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
