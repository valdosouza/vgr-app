import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/reports/data/reports_repository_impl.dart';
import 'package:vgr_admin/app/modules/reports/domain/entity/chat_evidence_entities.dart';
import 'package:vgr_admin/app/modules/reports/domain/entity/report_entities.dart';

class MockApiClient extends Mock implements ApiClient {}

/// B1 (decisions 158–167): the panel's report search + detail data layer.
void main() {
  late MockApiClient apiClient;
  late ReportsRepositoryImpl repository;

  setUp(() {
    apiClient = MockApiClient();
    repository = ReportsRepositoryImpl(apiClient);
  });

  Map<String, dynamic> emptyPage() => {'items': [], 'page': 1, 'pageSize': 20, 'total': 0};

  group('search — query string', () {
    test('only page/pageSize when no filter is set', () async {
      when(() => apiClient.get(any())).thenAnswer((_) async => emptyPage());

      await repository.search(const ReportFiltersEntity(), 1, 20);

      final path = verify(() => apiClient.get(captureAny())).captured.single as String;
      final uri = Uri.parse(path);
      expect(uri.path, '/api/reports');
      expect(uri.queryParameters, {'page': '1', 'pageSize': '20'});
    });

    test('every filter set is sent under the contract name', () async {
      when(() => apiClient.get(any())).thenAnswer((_) async => emptyPage());

      await repository.search(
        const ReportFiltersEntity(
          id: 5,
          status: 'open',
          category: 'assault',
          subject: 'child',
          tier: 'high',
          frozen: true,
          hasMedia: false,
          from: '2026-01-01',
          to: '2026-09-02',
        ),
        2,
        50,
      );

      final path = verify(() => apiClient.get(captureAny())).captured.single as String;
      expect(Uri.parse(path).queryParameters, {
        'page': '2',
        'pageSize': '50',
        'id': '5',
        'status': 'open',
        'category': 'assault',
        'subject': 'child',
        'tier': 'high',
        'frozen': 'true',
        'hasMedia': 'false',
        'from': '2026-01-01',
        'to': '2026-09-02',
      });
    });

    test('maps the paginated list, degraded position and null position when purged', () async {
      when(() => apiClient.get(any())).thenAnswer((_) async => {
            'items': [
              {
                'reportId': 7,
                'category': 'assault',
                'freeTag': null,
                'subject': 'child',
                'tier': 'high',
                'status': 'open',
                'anonymous': true,
                'frozen': false,
                'purged': false,
                'mediaCount': 2,
                'position': {'lat': -23.55, 'lng': -46.63},
                'createdAt': '2026-09-01T10:00:00.000Z',
                'resolvedAt': null,
              },
              {
                'reportId': 3,
                'category': null,
                'freeTag': 'noise',
                'subject': 'other',
                'tier': 'low',
                'status': 'resolved',
                'anonymous': false,
                'frozen': true,
                'purged': true,
                'mediaCount': 0,
                'position': null,
                'createdAt': '2026-01-01T10:00:00.000Z',
                'resolvedAt': '2026-02-01T10:00:00.000Z',
              },
            ],
            'page': 1,
            'pageSize': 20,
            'total': 42,
          });

      final result = await repository.search(const ReportFiltersEntity(), 1, 20);

      final page = result.getOrElse(() => throw StateError('left'));
      expect(page.total, 42);
      expect(page.items.length, 2);
      expect(page.items.first.position, const ReportPositionEntity(lat: -23.55, lng: -46.63));
      expect(page.items.first.mediaCount, 2);
      expect(page.items.last.position, isNull);
      expect(page.items.last.purged, isTrue);
      expect(page.items.last.freeTag, 'noise');
    });
  });

  group('getDetail — decisions 159/160/166', () {
    test('identified reporter maps to {accountId, displayName}; helpers likewise', () async {
      when(() => apiClient.get('/api/reports/7')).thenAnswer((_) async => {
            'reportId': 7,
            'category': 'assault',
            'freeTag': null,
            'subject': 'child',
            'tier': 'high',
            'status': 'open',
            'anonymous': false,
            'frozen': true,
            'frozenReason': 'Writ 1/2026',
            'frozenAt': '2026-09-01T11:00:00.000Z',
            'purged': false,
            'createdAt': '2026-09-01T10:00:00.000Z',
            'resolvedAt': null,
            'expiresAt': '2026-12-01T10:00:00.000Z',
            'reporter': {'accountId': 12, 'displayName': 'Maria'},
            'position': {'lat': -23.55, 'lng': -46.63, 'precisionMeters': 1100},
            'detailFields': {'weapon': 'knife', 'count': 2},
            'timeline': [
              {'eventType': 'created', 'payload': null, 'createdAt': '2026-09-01T10:00:00.000Z'},
            ],
            'media': [
              {'publicId': 'abc', 'mime': 'image/jpeg', 'width': 800, 'height': 600, 'status': 'available'},
            ],
            'offers': [
              {
                'helpOfferId': 1,
                'helpType': 'share',
                'anonymous': false,
                'helper': {'accountId': 30, 'displayName': 'João'},
                'createdAt': '2026-09-01T12:00:00.000Z',
              },
              {
                'helpOfferId': 2,
                'helpType': 'remote_support',
                'anonymous': true,
                'helper': null,
                'createdAt': '2026-09-01T13:00:00.000Z',
              },
            ],
          });

      final result = await repository.getDetail(7);

      final detail = result.getOrElse(() => throw StateError('left'));
      expect(detail.reporter, const ReportActorEntity(accountId: 12, displayName: 'Maria'));
      expect(detail.position?.precisionMeters, 1100);
      expect(detail.detailFields, {'weapon': 'knife', 'count': 2});
      expect(detail.timeline.single.eventType, 'created');
      expect(detail.media.single.status, 'available');
      expect(detail.offers.first.helper?.displayName, 'João');
      expect(detail.offers.last.helper, isNull);
      expect(detail.offers.last.anonymous, isTrue);
      expect(detail.frozenReason, 'Writ 1/2026');
      expect(detail.expiresAt, '2026-12-01T10:00:00.000Z');
    });

    test('anonymous report → reporter null; purged skeleton → nulls and empty lists', () async {
      when(() => apiClient.get('/api/reports/3')).thenAnswer((_) async => {
            'reportId': 3,
            'category': null,
            'freeTag': 'noise',
            'subject': 'other',
            'tier': 'low',
            'status': 'resolved',
            'anonymous': true,
            'frozen': false,
            'frozenReason': null,
            'frozenAt': null,
            'purged': true,
            'createdAt': '2026-01-01T10:00:00.000Z',
            'resolvedAt': '2026-02-01T10:00:00.000Z',
            'expiresAt': null,
            'reporter': null,
            'position': null,
            'detailFields': null,
            'timeline': [],
            'media': [],
            'offers': [],
          });

      final result = await repository.getDetail(3);

      final detail = result.getOrElse(() => throw StateError('left'));
      expect(detail.reporter, isNull);
      expect(detail.anonymous, isTrue);
      expect(detail.purged, isTrue);
      expect(detail.position, isNull);
      expect(detail.detailFields, isNull);
      expect(detail.timeline, isEmpty);
      expect(detail.media, isEmpty);
      expect(detail.offers, isEmpty);
    });

    test('404 surfaces as Left with the code intact', () async {
      when(() => apiClient.get('/api/reports/9')).thenThrow(
          const Failure(message: 'not found', statusCode: 404, code: 'NOT_FOUND'));

      final result = await repository.getDetail(9);

      expect(result.fold((f) => f.code, (_) => null), 'NOT_FOUND');
    });
  });

  test('getExactPosition reads the audited endpoint (decision 159)', () async {
    when(() => apiClient.get('/api/reports/7/position'))
        .thenAnswer((_) async => {'reportId': 7, 'lat': -23.5505, 'lng': -46.6333});

    final result = await repository.getExactPosition(7);

    final position = result.getOrElse(() => throw StateError('left'));
    expect(position, const ReportExactPositionEntity(reportId: 7, lat: -23.5505, lng: -46.6333));
  });

  group('embedded freeze calls — /api/case-freeze untouched (decisions 141/165)', () {
    test('getFreezeState maps the pending unfreeze', () async {
      when(() => apiClient.get('/api/case-freeze/7')).thenAnswer((_) async => {
            'reportId': 7,
            'status': 'open',
            'frozen': true,
            'frozenReason': 'Writ 1/2026',
            'frozenAt': '2026-09-01T11:00:00.000Z',
            'pendingUnfreeze': {
              'reason': 'Closed',
              'requestedBy': 4,
              'requestedAt': '2026-09-02T11:00:00.000Z',
            },
          });

      final result = await repository.getFreezeState(7);

      final state = result.getOrElse(() => throw StateError('left'));
      expect(state.frozen, isTrue);
      expect(state.pendingUnfreeze?.requestedBy, 4);
    });

    test('freeze / request / approve post to the three existing endpoints', () async {
      when(() => apiClient.post(any(), any())).thenAnswer((_) async => {});

      expect((await repository.freeze(7, 'Writ 1/2026')).isRight(), isTrue);
      expect((await repository.requestUnfreeze(7, 'Closed')).isRight(), isTrue);
      expect((await repository.approveUnfreeze(7)).isRight(), isTrue);

      verify(() => apiClient.post('/api/case-freeze/7/freeze', {'reason': 'Writ 1/2026'})).called(1);
      verify(() => apiClient.post('/api/case-freeze/7/unfreeze-request', {'reason': 'Closed'})).called(1);
      verify(() => apiClient.post('/api/case-freeze/7/unfreeze-approve', {})).called(1);
    });
  });

  group('moderation — B2 (decisions 162/163/165)', () {
    test('hide / unhide post the catalog reason to /api/reports/:id; note omitted when absent',
        () async {
      when(() => apiClient.post(any(), any())).thenAnswer((_) async => {});

      expect((await repository.hide(7, 'spam', null)).isRight(), isTrue);
      expect((await repository.unhide(7, 'other', 'Cleared by legal')).isRight(), isTrue);

      verify(() => apiClient.post('/api/reports/7/hide', {'reasonCode': 'spam'})).called(1);
      verify(() => apiClient.post('/api/reports/7/unhide',
          {'reasonCode': 'other', 'note': 'Cleared by legal'})).called(1);
    });

    test('blockMedia / unblockMedia post to /api/media/:publicId with the same body', () async {
      when(() => apiClient.post(any(), any())).thenAnswer((_) async => {});

      expect((await repository.blockMedia('abc', 'illegal_content', null)).isRight(), isTrue);
      expect((await repository.unblockMedia('abc', 'duplicate', '')).isRight(), isTrue);

      verify(() => apiClient.post('/api/media/abc/block', {'reasonCode': 'illegal_content'}))
          .called(1);
      verify(() => apiClient.post('/api/media/abc/unblock', {'reasonCode': 'duplicate'}))
          .called(1);
    });

    test('a 409 (already hidden) surfaces as Left with the code intact', () async {
      when(() => apiClient.post('/api/reports/7/hide', any())).thenThrow(
          const Failure(message: 'already', statusCode: 409, code: 'DUPLICATE'));

      final result = await repository.hide(7, 'abuse', null);

      expect(result.fold((f) => f.code, (_) => null), 'DUPLICATE');
    });

    test('list items carry `hidden` (false when the field is absent); the filter is sent',
        () async {
      when(() => apiClient.get(any())).thenAnswer((_) async => {
            'items': [
              {
                'reportId': 7, 'category': 'assault', 'freeTag': null, 'subject': 'child',
                'tier': 'high', 'status': 'open', 'anonymous': true, 'frozen': false,
                'purged': false, 'hidden': true, 'mediaCount': 0, 'position': null,
                'createdAt': '2026-09-01T10:00:00.000Z', 'resolvedAt': null,
              },
              {
                'reportId': 8, 'category': 'assault', 'freeTag': null, 'subject': 'child',
                'tier': 'high', 'status': 'open', 'anonymous': true, 'frozen': false,
                'purged': false, 'mediaCount': 0, 'position': null,
                'createdAt': '2026-09-01T10:00:00.000Z', 'resolvedAt': null,
              },
            ],
            'page': 1, 'pageSize': 20, 'total': 2,
          });

      final result = await repository.search(const ReportFiltersEntity(hidden: true), 1, 20);

      final path = verify(() => apiClient.get(captureAny())).captured.single as String;
      expect(Uri.parse(path).queryParameters['hidden'], 'true');
      final page = result.getOrElse(() => throw StateError('left'));
      expect(page.items.first.hidden, isTrue);
      expect(page.items.last.hidden, isFalse);
    });

    test("detail maps hidden* and each media item's blocked* fields", () async {
      when(() => apiClient.get('/api/reports/7')).thenAnswer((_) async => {
            'reportId': 7, 'category': 'assault', 'freeTag': null, 'subject': 'child',
            'tier': 'high', 'status': 'open', 'anonymous': true, 'frozen': false,
            'frozenReason': null, 'frozenAt': null, 'purged': false,
            'createdAt': '2026-09-01T10:00:00.000Z', 'resolvedAt': null, 'expiresAt': null,
            'hidden': true, 'hiddenReasonCode': 'abuse', 'hiddenNote': 'threats',
            'hiddenAt': '2026-09-02T09:00:00.000Z', 'hiddenBy': 4,
            'reporter': null, 'position': null, 'detailFields': null, 'timeline': [],
            'media': [
              {
                'publicId': 'abc', 'mime': 'image/jpeg', 'width': 800, 'height': 600,
                'status': 'blocked', 'blockedReasonCode': 'illegal_content',
                'blockedNote': null, 'blockedAt': '2026-09-02T09:05:00.000Z',
              },
              {'publicId': 'def', 'mime': 'image/png', 'width': null, 'height': null, 'status': 'available'},
            ],
            'offers': [],
          });

      final result = await repository.getDetail(7);

      final detail = result.getOrElse(() => throw StateError('left'));
      expect(detail.hidden, isTrue);
      expect(detail.hiddenReasonCode, 'abuse');
      expect(detail.hiddenNote, 'threats');
      expect(detail.hiddenAt, '2026-09-02T09:00:00.000Z');
      expect(detail.hiddenBy, 4);
      expect(detail.media.first.blockedReasonCode, 'illegal_content');
      expect(detail.media.first.blockedAt, '2026-09-02T09:05:00.000Z');
      expect(detail.media.last.blockedReasonCode, isNull);
      expect(detail.media.last.blockedAt, isNull);
    });
  });

  group('queue — B3 (decision 161)', () {
    test('queue(page, pageSize) reads GET /api/reports/queue and maps the queue fields on top '
        'of the ReportListItem shape', () async {
      when(() => apiClient.get(any())).thenAnswer((_) async => {
            'items': [
              {
                'reportId': 7, 'category': 'assault', 'freeTag': null, 'subject': 'child',
                'tier': 'high', 'status': 'open', 'anonymous': true, 'frozen': true,
                'purged': false, 'hidden': false, 'reviewed': false, 'mediaCount': 2,
                'position': {'lat': -23.55, 'lng': -46.63},
                'createdAt': '2026-09-01T10:00:00.000Z', 'resolvedAt': null,
                'priority': 'high', 'hasMedia': true, 'ageHours': 36,
              },
            ],
            'page': 2, 'pageSize': 50, 'total': 51,
          });

      final result = await repository.queue(2, 50);

      final path = verify(() => apiClient.get(captureAny())).captured.single as String;
      final uri = Uri.parse(path);
      expect(uri.path, '/api/reports/queue');
      expect(uri.queryParameters, {'page': '2', 'pageSize': '50'});
      final page = result.getOrElse(() => throw StateError('left'));
      expect(page.total, 51);
      expect(page.page, 2);
      expect(page.pageCount, 2);
      final entry = page.items.single;
      expect(entry.priority, 'high');
      expect(entry.hasMedia, isTrue);
      expect(entry.ageHours, 36);
      expect(entry.item.reportId, 7);
      expect(entry.item.frozen, isTrue);
      expect(entry.item.position, const ReportPositionEntity(lat: -23.55, lng: -46.63));
    });

    test('markReviewed posts to /api/reports/:id/reviewed with no body', () async {
      when(() => apiClient.post(any(), any())).thenAnswer((_) async => {});

      expect((await repository.markReviewed(7)).isRight(), isTrue);

      verify(() => apiClient.post('/api/reports/7/reviewed', {})).called(1);
    });

    test('a 409 (already reviewed) surfaces as Left with the code intact', () async {
      when(() => apiClient.post('/api/reports/7/reviewed', any())).thenThrow(
          const Failure(message: 'already', statusCode: 409, code: 'DUPLICATE'));

      final result = await repository.markReviewed(7);

      expect(result.fold((f) => f.code, (_) => null), 'DUPLICATE');
    });

    test('list items carry `reviewed` (false when absent); the tri-state filter is sent',
        () async {
      when(() => apiClient.get(any())).thenAnswer((_) async => {
            'items': [
              {
                'reportId': 7, 'category': 'assault', 'freeTag': null, 'subject': 'child',
                'tier': 'high', 'status': 'open', 'anonymous': true, 'frozen': false,
                'purged': false, 'reviewed': true, 'mediaCount': 0, 'position': null,
                'createdAt': '2026-09-01T10:00:00.000Z', 'resolvedAt': null,
              },
              {
                'reportId': 8, 'category': 'assault', 'freeTag': null, 'subject': 'child',
                'tier': 'high', 'status': 'open', 'anonymous': true, 'frozen': false,
                'purged': false, 'mediaCount': 0, 'position': null,
                'createdAt': '2026-09-01T10:00:00.000Z', 'resolvedAt': null,
              },
            ],
            'page': 1, 'pageSize': 20, 'total': 2,
          });

      final result = await repository.search(const ReportFiltersEntity(reviewed: false), 1, 20);

      final path = verify(() => apiClient.get(captureAny())).captured.single as String;
      expect(Uri.parse(path).queryParameters['reviewed'], 'false');
      final page = result.getOrElse(() => throw StateError('left'));
      expect(page.items.first.reviewed, isTrue);
      expect(page.items.last.reviewed, isFalse);
    });

    test('detail maps reviewedAt / reviewedBy (null when never reviewed or absent)', () async {
      when(() => apiClient.get('/api/reports/7')).thenAnswer((_) async => {
            'reportId': 7, 'category': 'assault', 'freeTag': null, 'subject': 'child',
            'tier': 'high', 'status': 'open', 'anonymous': true, 'frozen': false,
            'frozenReason': null, 'frozenAt': null, 'purged': false,
            'createdAt': '2026-09-01T10:00:00.000Z', 'resolvedAt': null, 'expiresAt': null,
            'reviewedAt': '2026-09-02T09:00:00.000Z', 'reviewedBy': 4,
            'reporter': null, 'position': null, 'detailFields': null, 'timeline': [],
            'media': [], 'offers': [],
          });
      when(() => apiClient.get('/api/reports/8')).thenAnswer((_) async => {
            'reportId': 8, 'category': 'assault', 'freeTag': null, 'subject': 'child',
            'tier': 'high', 'status': 'open', 'anonymous': true, 'frozen': false,
            'frozenReason': null, 'frozenAt': null, 'purged': false,
            'createdAt': '2026-09-01T10:00:00.000Z', 'resolvedAt': null, 'expiresAt': null,
            'reporter': null, 'position': null, 'detailFields': null, 'timeline': [],
            'media': [], 'offers': [],
          });

      final reviewed = (await repository.getDetail(7)).getOrElse(() => throw StateError('left'));
      final fresh = (await repository.getDetail(8)).getOrElse(() => throw StateError('left'));

      expect(reviewed.reviewedAt, '2026-09-02T09:00:00.000Z');
      expect(reviewed.reviewedBy, 4);
      expect(fresh.reviewedAt, isNull);
      expect(fresh.reviewedBy, isNull);
    });
  });

  group('chat evidence — C3 (decision 175): GET /api/reports/:id/chat', () {
    Map<String, dynamic> served({bool hasMore = false, bool includeHasMore = true}) => {
          'reportId': 7,
          'tier': 'high',
          'threads': [
            {
              'threadId': 3,
              'helpOfferId': 11,
              'createdAt': '2026-09-03T10:00:00.000Z',
              'closed': true,
              if (includeHasMore) 'hasMore': hasMore,
              'participants': [
                {
                  'role': 'reporter',
                  'participantToken': 'a' * 32,
                  'accountId': null,
                  'displayName': null,
                  'anonymousChoice': true,
                },
                {
                  'role': 'helper',
                  'participantToken': 'b' * 32,
                  'accountId': 30,
                  'displayName': 'João',
                  'anonymousChoice': false,
                },
              ],
              'messages': [
                {
                  'messageId': 100,
                  'sender': 'b' * 32,
                  'text': 'Where are you?',
                  'purged': false,
                  'createdAt': '2026-09-03T10:01:02.000Z',
                },
                {
                  'messageId': 101,
                  'sender': 'a' * 32,
                  'text': null,
                  'purged': true,
                  'createdAt': '2026-09-03T10:02:00.000Z',
                },
              ],
            },
          ],
        };

    test('getChat(id) reads /api/reports/:id/chat with no query when limit is not given',
        () async {
      when(() => apiClient.get(any())).thenAnswer((_) async => served());

      await repository.getChat(7);

      final path = verify(() => apiClient.get(captureAny())).captured.single as String;
      expect(path, '/api/reports/7/chat');
    });

    test('getChat(id, limit) sends ?limit=', () async {
      when(() => apiClient.get(any())).thenAnswer((_) async => served());

      await repository.getChat(7, limit: 50);

      final path = verify(() => apiClient.get(captureAny())).captured.single as String;
      final uri = Uri.parse(path);
      expect(uri.path, '/api/reports/7/chat');
      expect(uri.queryParameters, {'limit': '50'});
    });

    test('maps threads, participants (null identity for the anonymous reporter, '
        'accountId + displayName for the helper), messages incl. purged text', () async {
      when(() => apiClient.get(any())).thenAnswer((_) async => served(hasMore: true));

      final result = await repository.getChat(7);

      final chat = result.getOrElse(() => throw StateError('left'));
      expect(chat.reportId, 7);
      expect(chat.tier, 'high');
      expect(chat.threads, hasLength(1));
      final thread = chat.threads.single;
      expect(thread.threadId, 3);
      expect(thread.helpOfferId, 11);
      expect(thread.createdAt, '2026-09-03T10:00:00.000Z');
      expect(thread.closed, isTrue);
      expect(thread.hasMore, isTrue);
      expect(thread.participants, [
        ChatParticipantEvidenceEntity(
          role: 'reporter',
          participantToken: 'a' * 32,
          accountId: null,
          displayName: null,
          anonymousChoice: true,
        ),
        ChatParticipantEvidenceEntity(
          role: 'helper',
          participantToken: 'b' * 32,
          accountId: 30,
          displayName: 'João',
          anonymousChoice: false,
        ),
      ]);
      expect(thread.messages, [
        ChatMessageEvidenceEntity(
          messageId: 100,
          sender: 'b' * 32,
          text: 'Where are you?',
          purged: false,
          createdAt: '2026-09-03T10:01:02.000Z',
        ),
        ChatMessageEvidenceEntity(
          messageId: 101,
          sender: 'a' * 32,
          text: null,
          purged: true,
          createdAt: '2026-09-03T10:02:00.000Z',
        ),
      ]);
    });

    test('hasMore absent → false; a case with no thread → empty list', () async {
      when(() => apiClient.get('/api/reports/7/chat'))
          .thenAnswer((_) async => served(includeHasMore: false));
      when(() => apiClient.get('/api/reports/8/chat'))
          .thenAnswer((_) async => {'reportId': 8, 'tier': 'low', 'threads': []});

      final withThread = await repository.getChat(7);
      final without = await repository.getChat(8);

      expect(withThread.getOrElse(() => throw StateError('left')).threads.single.hasMore, isFalse);
      expect(without.getOrElse(() => throw StateError('left')).threads, isEmpty);
    });

    test('a 403 (reports VIEW only, no chat_evidence) surfaces as Left with the code intact',
        () async {
      when(() => apiClient.get('/api/reports/7/chat')).thenThrow(
          const Failure(message: 'no', statusCode: 403, code: 'FORBIDDEN'));

      final result = await repository.getChat(7);

      expect(result.fold((f) => f.code, (_) => null), 'FORBIDDEN');
    });
  });
}
