import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../rating/domain/usecase/rate_offer_usecase.dart';
import '../../data/my_reports_store.dart';
import '../../domain/entity/report_view_entity.dart';
import '../../domain/usecase/get_report_view_usecase.dart';
import '../../domain/usecase/resolve_report_usecase.dart';

sealed class ReportDetailEvent extends Equatable {
  const ReportDetailEvent();

  @override
  List<Object?> get props => [];
}

class DetailStarted extends ReportDetailEvent {
  const DetailStarted(this.reportId);

  final int reportId;

  @override
  List<Object?> get props => [reportId];
}

/// The owner closes the case (decisions 18/131/179) — the page already
/// confirmed with the user via `showVgrConfirm` before dispatching this.
class DetailResolvePressed extends ReportDetailEvent {
  const DetailResolvePressed();
}

/// The owner rates a resolved, ratable offer (decisions 48/178-189) — the
/// page only dispatches this for a star the offer's own `ratable` flag
/// allowed tapping.
class DetailRatePressed extends ReportDetailEvent {
  const DetailRatePressed({required this.offerId, required this.score});

  final int offerId;
  final int score;

  @override
  List<Object?> get props => [offerId, score];
}

sealed class ReportDetailState extends Equatable {
  const ReportDetailState();

  @override
  List<Object?> get props => [];
}

class DetailLoading extends ReportDetailState {
  const DetailLoading();
}

class DetailLoaded extends ReportDetailState {
  const DetailLoaded(
    this.view, {
    this.clientKey,
    this.resolving = false,
    this.ratingOfferId,
    this.actionFailure,
  });

  final ReportViewEntity view;

  /// Present when this device owns the report (decision 134) — the page
  /// sends it as `x-client-key` when streaming media derivatives.
  final String? clientKey;

  /// True while `DetailResolvePressed` is in flight — the button shows a
  /// spinner and refuses a second tap.
  final bool resolving;

  /// The offer currently submitting a rating, if any — disables every
  /// star on that one row so a second tap cannot race the first (183:
  /// one rating per offer, immutable).
  final int? ratingOfferId;

  /// The last resolve/rate refusal, surfaced inline; cleared on the next
  /// attempt of either action.
  final Failure? actionFailure;

  DetailLoaded copyWith({
    ReportViewEntity? view,
    String? clientKey,
    bool? resolving,
    int? ratingOfferId,
    bool clearRatingOfferId = false,
    Failure? actionFailure,
    bool clearActionFailure = false,
  }) =>
      DetailLoaded(
        view ?? this.view,
        clientKey: clientKey ?? this.clientKey,
        resolving: resolving ?? this.resolving,
        ratingOfferId: clearRatingOfferId ? null : (ratingOfferId ?? this.ratingOfferId),
        actionFailure: clearActionFailure ? null : (actionFailure ?? this.actionFailure),
      );

  @override
  List<Object?> get props => [view, clientKey, resolving, ratingOfferId, actionFailure];
}

class DetailError extends ReportDetailState {
  const DetailError(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// Loads the server-resolved view (spec task 22, decision 50) and drives
/// the owner-only close (RT2, 18/131/179) and per-offer rating (RT2,
/// 48/178-189) actions the detail page renders over it.
class ReportDetailBloc extends Bloc<ReportDetailEvent, ReportDetailState> {
  ReportDetailBloc(
    this._getReportView,
    this._myReports,
    this._resolveReport,
    this._rateOffer,
  ) : super(const DetailLoading()) {
    on<DetailStarted>(_onStarted);
    on<DetailResolvePressed>(_onResolvePressed);
    on<DetailRatePressed>(_onRatePressed);
  }

  final GetReportViewUsecase _getReportView;
  final MyReportsStore _myReports;
  final ResolveReportUsecase _resolveReport;
  final RateOfferUsecase _rateOffer;

  int? _reportId;

  Future<void> _onStarted(DetailStarted event, Emitter<ReportDetailState> emit) async {
    _reportId = event.reportId;
    emit(const DetailLoading());
    await _load(event.reportId, emit);
  }

  Future<void> _load(int reportId, Emitter<ReportDetailState> emit) async {
    final result = await _getReportView(reportId);
    if (emit.isDone) return;
    final clientKey = await _myReports.clientKeyOf(reportId);
    result.fold(
      (failure) => emit(DetailError(failure)),
      (view) => emit(DetailLoaded(view, clientKey: clientKey)),
    );
  }

  Future<void> _onResolvePressed(
    DetailResolvePressed event,
    Emitter<ReportDetailState> emit,
  ) async {
    final current = state;
    final reportId = _reportId;
    if (current is! DetailLoaded || reportId == null) return;

    emit(current.copyWith(resolving: true, clearActionFailure: true));
    final result = await _resolveReport(reportId);
    if (emit.isDone) return;
    final failure = result.fold((f) => f, (_) => null);
    // Judgment call (RT2 plan): the resolve endpoint's ONLY business-rule
    // refusal is "already resolved" — an ack that never reached this
    // device after a first attempt DID succeed lands here identically to
    // a genuine double-close. Either way the case IS resolved, so this
    // one outcome is treated as success and the view reloads like any
    // other; every other refusal (404 non-owner, 451 legal) surfaces.
    final effectivelyResolved =
        failure == null || (failure.statusCode == 422 && failure.code == 'BUSINESS_RULE');
    if (!effectivelyResolved) {
      final latest = state;
      if (latest is DetailLoaded) {
        emit(latest.copyWith(resolving: false, actionFailure: failure));
      }
      return;
    }
    await _load(reportId, emit);
  }

  Future<void> _onRatePressed(
    DetailRatePressed event,
    Emitter<ReportDetailState> emit,
  ) async {
    final current = state;
    final reportId = _reportId;
    if (current is! DetailLoaded || reportId == null) return;
    if (current.ratingOfferId != null) return; // already submitting one

    final offer = _offerById(current.view.offers, event.offerId);
    // Defensive: the server's `ratable` is the only authority (never
    // recomputed here) — this just avoids a pointless call on a stale UI.
    if (offer == null || offer.rating?.ratable != true) return;

    emit(current.copyWith(ratingOfferId: event.offerId, clearActionFailure: true));
    final result = await _rateOffer(reportId: reportId, offerId: event.offerId, score: event.score);
    if (emit.isDone) return;
    final latest = state;
    if (latest is! DetailLoaded) return;

    result.fold(
      (failure) => emit(latest.copyWith(clearRatingOfferId: true, actionFailure: failure)),
      (outcome) {
        // Either the server already answered with the exact score
        // (online) or it is queued for later (181, offline) — either way
        // this screen treats the offer as rated now so a second tap
        // cannot race the first (183: one rating per offer, immutable).
        // A queued rating is confirmed for real on the next full reload.
        final score = outcome.rating?.score ?? event.score;
        final offers = (latest.view.offers ?? const [])
            .map((o) => o.helpOfferId == event.offerId
                ? OfferViewEntity(
                    helpOfferId: o.helpOfferId,
                    helpType: o.helpType,
                    helperDisplayName: o.helperDisplayName,
                    createdAt: o.createdAt,
                    rating: OfferRatingEntity(score: score, ratable: false),
                  )
                : o)
            .toList();
        emit(latest.copyWith(
          view: latest.view.copyWithOffers(offers),
          clearRatingOfferId: true,
        ));
      },
    );
  }

  OfferViewEntity? _offerById(List<OfferViewEntity>? offers, int offerId) {
    if (offers == null) return null;
    for (final offer in offers) {
      if (offer.helpOfferId == offerId) return offer;
    }
    return null;
  }
}
