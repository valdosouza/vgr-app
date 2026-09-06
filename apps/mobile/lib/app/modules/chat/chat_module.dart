import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../shared/data/my_reports_store.dart';
import 'data/chat_repository_impl.dart';
import 'data/chat_send_outcomes.dart';
import 'domain/entity/chat_entities.dart';
import 'domain/repository/chat_repository.dart';
import 'domain/usecase/fetch_chat_messages_usecase.dart';
import 'domain/usecase/list_chat_threads_usecase.dart';
import 'domain/usecase/send_chat_message_usecase.dart';
import 'presentation/bloc/chat_conversation_bloc.dart';
import 'presentation/bloc/chat_threads_bloc.dart';
import 'presentation/page/chat_conversation_page.dart';
import 'presentation/page/chat_threads_page.dart';

/// Masked chat (C2 — decisions 54, 168-177), mounted at `/chat`.
class ChatModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<ChatRepository>(
          (i) => ChatRepositoryImpl(
            i.get<ApiClient>(),
            i.get<OfflineQueueService>(),
            // Ownership header of the anonymous reporter (134/169) — the
            // same store the report module writes on submit.
            i.get<MyReportsStore>(),
            i.get<ChatSendOutcomes>(),
          ),
        ),
        Bind.factory((i) => ChatThreadsBloc(ListChatThreadsUsecase(i.get<ChatRepository>()))),
        Bind.factory(
          (i) => ChatConversationBloc(
            FetchChatMessagesUsecase(i.get<ChatRepository>()),
            SendChatMessageUsecase(i.get<ChatRepository>()),
            i.get<ChatRepository>().sendOutcomes,
          ),
        ),
      ];

  @override
  List<ModularRoute> get routes => [
        // Literal segment first so 'threads' never parses as a report id.
        ChildRoute(
          '/threads/:reportId',
          child: (_, args) => BlocProvider(
            create: (_) => Modular.get<ChatThreadsBloc>(),
            child: ChatThreadsPage(
              reportId: int.parse(args.params['reportId'] as String),
            ),
          ),
        ),
        // `threadId` is `new` for a helper's first message (173). Without
        // arguments (deep link) the other side is labeled by ROLE only —
        // the screen never derives a name (170).
        ChildRoute(
          '/:reportId/thread/:threadId',
          child: (_, args) {
            final rawThreadId = args.params['threadId'] as String;
            final data = args.data;
            final conversation = data is ChatConversationArgs
                ? data
                : const ChatConversationArgs(otherRole: ChatRole.reporter);
            return BlocProvider(
              create: (_) => Modular.get<ChatConversationBloc>(),
              child: ChatConversationPage(
                reportId: int.parse(args.params['reportId'] as String),
                threadId: rawThreadId == 'new' ? null : int.parse(rawThreadId),
                otherRole: conversation.otherRole,
                otherName: conversation.otherName,
              ),
            );
          },
        ),
      ];
}
