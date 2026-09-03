import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/chat_entities.dart';
import '../../domain/usecase/list_chat_threads_usecase.dart';

sealed class ChatThreadsEvent extends Equatable {
  const ChatThreadsEvent();

  @override
  List<Object?> get props => [];
}

class ThreadsStarted extends ChatThreadsEvent {
  const ThreadsStarted(this.reportId);

  final int reportId;

  @override
  List<Object?> get props => [reportId];
}

sealed class ChatThreadsState extends Equatable {
  const ChatThreadsState();

  @override
  List<Object?> get props => [];
}

class ThreadsLoading extends ChatThreadsState {
  const ThreadsLoading();
}

class ThreadsLoaded extends ChatThreadsState {
  const ThreadsLoaded(this.threads);

  final List<ChatThreadSummaryEntity> threads;

  @override
  List<Object?> get props => [threads];
}

class ThreadsError extends ChatThreadsState {
  const ThreadsError(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// The owner's conversations, one per helper (decisions 55/170).
class ChatThreadsBloc extends Bloc<ChatThreadsEvent, ChatThreadsState> {
  ChatThreadsBloc(this._listThreads) : super(const ThreadsLoading()) {
    on<ThreadsStarted>(_onStarted);
  }

  final ListChatThreadsUsecase _listThreads;

  Future<void> _onStarted(ThreadsStarted event, Emitter<ChatThreadsState> emit) async {
    emit(const ThreadsLoading());
    final result = await _listThreads(event.reportId);
    if (emit.isDone) return;
    result.fold(
      (failure) => emit(ThreadsError(failure)),
      (threads) => emit(ThreadsLoaded(threads)),
    );
  }
}
