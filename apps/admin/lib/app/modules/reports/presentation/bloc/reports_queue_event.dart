import 'package:equatable/equatable.dart';

sealed class ReportsQueueEvent extends Equatable {
  const ReportsQueueEvent();

  @override
  List<Object?> get props => [];
}

/// Load page 1 of the queue (on entry).
class ReportsQueueRequested extends ReportsQueueEvent {
  const ReportsQueueRequested();
}

/// Prev/next.
class ReportsQueuePageRequested extends ReportsQueueEvent {
  const ReportsQueuePageRequested(this.page);

  final int page;

  @override
  List<Object?> get props => [page];
}

/// ONE human marks the case reviewed (decision 161); audited server-side.
class ReportsQueueMarkReviewed extends ReportsQueueEvent {
  const ReportsQueueMarkReviewed(this.reportId);

  final int reportId;

  @override
  List<Object?> get props => [reportId];
}
