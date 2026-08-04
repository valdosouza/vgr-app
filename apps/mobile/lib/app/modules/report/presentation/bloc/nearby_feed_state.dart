import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entity/feed_item_entity.dart';

/// Buildable states of the feed (spec 1.4): Loading / Loaded / Empty /
/// Error, each rendered distinctly.
sealed class NearbyFeedState extends Equatable {
  const NearbyFeedState();

  @override
  List<Object?> get props => [];
}

class FeedLoading extends NearbyFeedState {
  const FeedLoading();
}

class FeedLoaded extends NearbyFeedState {
  const FeedLoaded({
    required this.items,
    required this.page,
    required this.hasMore,
    required this.order,
    this.loadingMore = false,
  });

  final List<FeedItemEntity> items;
  final int page;
  final bool hasMore;
  final FeedOrder order;
  final bool loadingMore;

  FeedLoaded copyWith({
    List<FeedItemEntity>? items,
    int? page,
    bool? hasMore,
    FeedOrder? order,
    bool? loadingMore,
  }) =>
      FeedLoaded(
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        order: order ?? this.order,
        loadingMore: loadingMore ?? this.loadingMore,
      );

  @override
  List<Object?> get props => [items, page, hasMore, order, loadingMore];
}

class FeedEmpty extends NearbyFeedState {
  const FeedEmpty(this.order);

  final FeedOrder order;

  @override
  List<Object?> get props => [order];
}

class FeedError extends NearbyFeedState {
  const FeedError(this.failure, this.order);

  final Failure failure;
  final FeedOrder order;

  @override
  List<Object?> get props => [failure, order];
}
