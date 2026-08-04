import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/report_view_entity.dart';
import '../../domain/usecase/get_report_view_usecase.dart';
import '../../data/my_reports_store.dart';

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

sealed class ReportDetailState extends Equatable {
  const ReportDetailState();

  @override
  List<Object?> get props => [];
}

class DetailLoading extends ReportDetailState {
  const DetailLoading();
}

class DetailLoaded extends ReportDetailState {
  const DetailLoaded(this.view, {this.clientKey});

  final ReportViewEntity view;

  /// Present when this device owns the report (decision 134) — the page
  /// sends it as `x-client-key` when streaming media derivatives.
  final String? clientKey;

  @override
  List<Object?> get props => [view, clientKey];
}

class DetailError extends ReportDetailState {
  const DetailError(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// Loads the server-resolved view (spec task 22, decision 50).
class ReportDetailBloc extends Bloc<ReportDetailEvent, ReportDetailState> {
  ReportDetailBloc(this._getReportView, this._myReports) : super(const DetailLoading()) {
    on<DetailStarted>(_onStarted);
  }

  final GetReportViewUsecase _getReportView;
  final MyReportsStore _myReports;

  Future<void> _onStarted(DetailStarted event, Emitter<ReportDetailState> emit) async {
    emit(const DetailLoading());
    final result = await _getReportView(event.reportId);
    if (emit.isDone) return;
    final clientKey = await _myReports.clientKeyOf(event.reportId);
    result.fold(
      (failure) => emit(DetailError(failure)),
      (view) => emit(DetailLoaded(view, clientKey: clientKey)),
    );
  }
}
