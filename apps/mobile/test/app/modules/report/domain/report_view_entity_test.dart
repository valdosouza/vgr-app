import 'package:flutter_test/flutter_test.dart';
import 'package:vgr_mobile/app/modules/report/domain/entity/report_view_entity.dart';

Map<String, dynamic> _owner({bool? hidden}) => {
      'access': 'owner',
      'reportId': 5,
      'category': 'assault',
      'subject': 'adult',
      'tier': 'high',
      'status': 'open',
      if (hidden != null) 'hidden': hidden,
    };

void main() {
  group('ReportViewEntity.hidden — the owner\'s mark (B2, decision 167)', () {
    test('defaults to false when the API does not send the field', () {
      expect(ReportViewEntity.fromJson(_owner()).hidden, isFalse);
    });

    test('reads the flag when present, and it takes part in equality', () {
      final hidden = ReportViewEntity.fromJson(_owner(hidden: true));
      expect(hidden.hidden, isTrue);
      expect(hidden, isNot(ReportViewEntity.fromJson(_owner(hidden: false))));
    });
  });

  group('ReportViewEntity.chat — the served chat facet (C2, decision 169)', () {
    test('absent → null (public and summary views, anonymous helper)', () {
      expect(ReportViewEntity.fromJson(_owner()).chat, isNull);
    });

    test('owner: {threads, unread}', () {
      final view = ReportViewEntity.fromJson({..._owner(), 'chat': {'threads': 2, 'unread': 3}});
      expect(view.chat, const ReportChatFacetEntity(threads: 2, unread: 3));
      expect(view.chat!.isOwner, isTrue);
    });

    test('helper participant: {threadId, unread}, threadId null before the first message', () {
      final withThread = ReportViewEntity.fromJson(
          {..._owner(), 'access': 'participant', 'chat': {'threadId': 9, 'unread': 1}});
      expect(withThread.chat, const ReportChatFacetEntity(threadId: 9, unread: 1));
      expect(withThread.chat!.isOwner, isFalse);

      final noThread = ReportViewEntity.fromJson(
          {..._owner(), 'access': 'participant', 'chat': {'threadId': null, 'unread': 0}});
      expect(noThread.chat!.threadId, isNull);
      expect(noThread.chat!.isOwner, isFalse);
    });
  });
}
