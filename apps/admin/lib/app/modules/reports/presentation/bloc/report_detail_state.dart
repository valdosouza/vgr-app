import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entity/chat_evidence_entities.dart';
import '../../domain/entity/report_entities.dart';

sealed class ReportDetailState extends Equatable {
  const ReportDetailState();

  @override
  List<Object?> get props => [];
}

class ReportDetailInitial extends ReportDetailState {
  const ReportDetailInitial();
}

class ReportDetailLoading extends ReportDetailState {
  const ReportDetailLoading();
}

/// The case is on screen. [freeze] is `null` when `/api/case-freeze`
/// refused (no `case_freeze` grant) — the detail still renders. [busy]
/// while a mutation is in flight; [failure] carries the last action error
/// without losing the case; [exactPosition] only after an audited reveal;
/// [chat] only after an audited "Load chat" (C3, decision 175) — [chatLoading]
/// while that read is in flight, [chatFailure] when the server refused it.
class ReportDetailLoaded extends ReportDetailState {
  const ReportDetailLoaded(
    this.detail, {
    required this.freeze,
    this.busy = false,
    this.failure,
    this.exactPosition,
    this.chat,
    this.chatLoading = false,
    this.chatFailure,
  });

  final ReportPanelDetailEntity detail;
  final ReportFreezeStateEntity? freeze;
  final bool busy;
  final Failure? failure;
  final ReportExactPositionEntity? exactPosition;
  final ReportChatEntity? chat;
  final bool chatLoading;
  final Failure? chatFailure;

  /// [failure] and [chatFailure] are one-shot: absent unless passed again.
  ReportDetailLoaded copyWith({
    bool? busy,
    Failure? failure,
    ReportExactPositionEntity? exactPosition,
    ReportChatEntity? chat,
    bool? chatLoading,
    Failure? chatFailure,
  }) =>
      ReportDetailLoaded(
        detail,
        freeze: freeze,
        busy: busy ?? this.busy,
        failure: failure,
        exactPosition: exactPosition ?? this.exactPosition,
        chat: chat ?? this.chat,
        chatLoading: chatLoading ?? this.chatLoading,
        chatFailure: chatFailure,
      );

  @override
  List<Object?> get props =>
      [detail, freeze, busy, failure, exactPosition, chat, chatLoading, chatFailure];
}

/// The detail itself failed (404, no grant).
class ReportDetailError extends ReportDetailState {
  const ReportDetailError(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
