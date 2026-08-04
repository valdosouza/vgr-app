import 'package:equatable/equatable.dart';

import '../../domain/entity/feed_item_entity.dart';

sealed class NearbyFeedEvent extends Equatable {
  const NearbyFeedEvent();

  @override
  List<Object?> get props => [];
}

/// First load (and retry after an error): locate + fetch page 1.
class FeedStarted extends NearbyFeedEvent {
  const FeedStarted();
}

class FeedNextPageRequested extends NearbyFeedEvent {
  const FeedNextPageRequested();
}

class FeedOrderChanged extends NearbyFeedEvent {
  const FeedOrderChanged(this.order);

  final FeedOrder order;

  @override
  List<Object?> get props => [order];
}
