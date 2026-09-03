import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entity/report_entities.dart';

sealed class ReportsQueueState extends Equatable {
  const ReportsQueueState();

  @override
  List<Object?> get props => [];
}

class ReportsQueueInitial extends ReportsQueueState {
  const ReportsQueueInitial();
}

class ReportsQueueLoading extends ReportsQueueState {
  const ReportsQueueLoading();
}

/// The queue page is on screen. [busy] while a mark is in flight;
/// [failure] carries the last refused mark (409 already reviewed, 403)
/// without losing the rows.
class ReportsQueueLoaded extends ReportsQueueState {
  const ReportsQueueLoaded(this.page, {this.busy = false, this.failure});

  final QueuePageEntity page;
  final bool busy;
  final Failure? failure;

  ReportsQueueLoaded copyWith({bool? busy, Failure? failure}) =>
      ReportsQueueLoaded(page, busy: busy ?? this.busy, failure: failure);

  @override
  List<Object?> get props => [page, busy, failure];
}

/// The queue read itself failed (no grant, network).
class ReportsQueueError extends ReportsQueueState {
  const ReportsQueueError(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
