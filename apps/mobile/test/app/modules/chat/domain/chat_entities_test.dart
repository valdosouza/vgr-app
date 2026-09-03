import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vgr_mobile/app/modules/chat/domain/entity/chat_entities.dart';

/// JSON mapping of what `/app-chat` serves (api/docs/feature/chat.md).
/// The app renders role + displayName EXACTLY as served (decision 170) —
/// there is no fallback, no lookup, no guess about who someone is.
void main() {
  group('ChatParticipantEntity', () {
    test('maps token, role and a served display name', () {
      final helper = ChatParticipantEntity.fromJson(const {
        'participantToken': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        'role': 'helper',
        'displayName': 'Ana',
      });
      expect(helper.role, ChatRole.helper);
      expect(helper.displayName, 'Ana');
    });

    test('a null displayName stays null — the reporter never has one (170)', () {
      final reporter = ChatParticipantEntity.fromJson(const {
        'participantToken': 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        'role': 'reporter',
        'displayName': null,
      });
      expect(reporter.role, ChatRole.reporter);
      expect(reporter.displayName, isNull);
    });
  });

  group('ChatThreadSummaryEntity', () {
    test('maps the owner\'s row: other participant, degraded time, unread, closed', () {
      final thread = ChatThreadSummaryEntity.fromJson(const {
        'threadId': 9,
        'reportId': 5,
        'me': {'participantToken': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 'role': 'reporter', 'displayName': null},
        'other': {'participantToken': 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb', 'role': 'helper', 'displayName': null},
        'lastMessageAt': '2026-09-03T10:15:00.000Z',
        'unreadCount': 2,
        'closed': false,
      });
      expect(thread.threadId, 9);
      expect(thread.other.role, ChatRole.helper);
      expect(thread.lastMessageAt, '2026-09-03T10:15:00.000Z');
      expect(thread.unreadCount, 2);
      expect(thread.closed, isFalse);
    });

    test('lastMessageAt null before the first message', () {
      final thread = ChatThreadSummaryEntity.fromJson(const {
        'threadId': 9,
        'reportId': 5,
        'me': {'participantToken': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 'role': 'helper', 'displayName': 'Ana'},
        'other': {'participantToken': 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb', 'role': 'reporter', 'displayName': null},
        'lastMessageAt': null,
        'unreadCount': 0,
        'closed': true,
      });
      expect(thread.lastMessageAt, isNull);
      expect(thread.closed, isTrue);
    });
  });

  group('ChatMessageEntity', () {
    test('a served message is `sent`, with the timestamp as served (174)', () {
      final message = ChatMessageEntity.fromJson(const {
        'messageId': 41,
        'clientKey': 'ck-1',
        'sender': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        'mine': true,
        'text': 'oi',
        'purged': false,
        'createdAt': '2026-09-03T10:15:00.000Z',
      });
      expect(message.status, ChatMessageStatus.sent);
      expect(message.messageId, 41);
      expect(message.mine, isTrue);
      expect(message.createdAt, '2026-09-03T10:15:00.000Z');
      expect(message.failure, isNull);
    });

    test('a purged message has null text and the flag (131/173)', () {
      final message = ChatMessageEntity.fromJson(const {
        'messageId': 41,
        'clientKey': 'ck-1',
        'sender': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        'mine': false,
        'text': null,
        'purged': true,
        'createdAt': '2026-09-03T10:15:00.000Z',
      });
      expect(message.text, isNull);
      expect(message.purged, isTrue);
    });

    test('an optimistic message is `pending` with no id; failure code comes from the '
        'field error first, then the envelope code', () {
      const pending = ChatMessageEntity(
        clientKey: 'ck-2',
        mine: true,
        text: 'oi',
        createdAt: '2026-09-03T10:16:00.000Z',
        status: ChatMessageStatus.pending,
      );
      expect(pending.messageId, isNull);
      expect(pending.failureCode, isNull);

      final contact = pending.copyWith(
        status: ChatMessageStatus.failed,
        failure: const Failure(
          message: 'x',
          statusCode: 422,
          code: 'CONTACT_NOT_ALLOWED',
          fields: [
            FieldFailure(field: 'text', message: 'x', code: 'CONTACT_NOT_ALLOWED',
                params: {'kind': 'phone', 'match': '91234567'}),
          ],
        ),
      );
      expect(contact.failureCode, 'CONTACT_NOT_ALLOWED');

      final closed = pending.copyWith(
        status: ChatMessageStatus.failed,
        failure: const Failure(message: 'x', statusCode: 409, code: 'CHAT_CLOSED'),
      );
      expect(closed.failureCode, 'CHAT_CLOSED');
    });
  });

  group('ChatPageEntity', () {
    test('maps the cursor page', () {
      final page = ChatPageEntity.fromJson(const {
        'threadId': 9,
        'closed': false,
        'tier': 'medium',
        'messages': [
          {
            'messageId': 41,
            'clientKey': 'ck-1',
            'sender': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'mine': true,
            'text': 'oi',
            'purged': false,
            'createdAt': '2026-09-03T10:15:00.000Z',
          },
        ],
      });
      expect(page.threadId, 9);
      expect(page.tier, 'medium');
      expect(page.messages.single.messageId, 41);
    });
  });
}
