import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/feed_item_entity.dart';
import '../../domain/gateway/location_gateway.dart';
import '../../domain/usecase/list_nearby_reports_usecase.dart';
import 'nearby_feed_event.dart';
import 'nearby_feed_state.dart';

/// Paginated nearby feed (spec task 07, decisions 2/21/135). The viewer
/// position is read once per (re)start and used transiently — never
/// stored (decision 110).
class NearbyFeedBloc extends Bloc<NearbyFeedEvent, NearbyFeedState> {
  NearbyFeedBloc(this._listNearby, this._locationGateway) : super(const FeedLoading()) {
    on<FeedStarted>(_onStarted);
    on<FeedOrderChanged>(_onOrderChanged);
    on<FeedNextPageRequested>(_onNextPage);
  }

  final ListNearbyReportsUsecase _listNearby;
  final LocationGateway _locationGateway;

  GeoPoint? _position;
  FeedOrder _order = FeedOrder.recency;

  Future<void> _onStarted(FeedStarted event, Emitter<NearbyFeedState> emit) =>
      _loadFirstPage(emit);

  Future<void> _onOrderChanged(
    FeedOrderChanged event,
    Emitter<NearbyFeedState> emit,
  ) async {
    if (event.order == _order) return;
    _order = event.order;
    await _loadFirstPage(emit);
  }

  Future<void> _loadFirstPage(Emitter<NearbyFeedState> emit) async {
    emit(const FeedLoading());

    if (_position == null) {
      final located = await _locationGateway.currentPosition();
      final failure = located.fold((f) => f, (point) {
        _position = point;
        return null;
      });
      if (failure != null) {
        emit(FeedError(failure, _order));
        return;
      }
    }

    final result = await _listNearby(_position!, 1, _order);
    result.fold(
      (failure) => emit(FeedError(failure, _order)),
      (page) => emit(page.items.isEmpty
          ? FeedEmpty(_order)
          : FeedLoaded(
              items: page.items,
              page: page.page,
              hasMore: page.hasMore,
              order: _order,
            )),
    );
  }

  Future<void> _onNextPage(
    FeedNextPageRequested event,
    Emitter<NearbyFeedState> emit,
  ) async {
    final current = state;
    if (current is! FeedLoaded ||
        !current.hasMore ||
        current.loadingMore ||
        _position == null) {
      return;
    }
    emit(current.copyWith(loadingMore: true));

    final result = await _listNearby(_position!, current.page + 1, _order);
    result.fold(
      // Keep what we have — the next tap retries the same page.
      (_) => emit(current.copyWith(loadingMore: false)),
      (page) {
        // Append without duplicating (spec task 07 acceptance): the feed
        // moves under pagination, so a row may show up on two pages.
        final known = current.items.map((i) => i.reportId).toSet();
        emit(FeedLoaded(
          items: [
            ...current.items,
            ...page.items.where((i) => !known.contains(i.reportId)),
          ],
          page: page.page,
          hasMore: page.hasMore,
          order: _order,
        ));
      },
    );
  }
}
