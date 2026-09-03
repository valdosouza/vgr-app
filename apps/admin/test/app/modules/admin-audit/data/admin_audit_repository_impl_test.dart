import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/admin-audit/data/admin_audit_repository_impl.dart';
import 'package:vgr_admin/app/modules/admin-audit/domain/entity/admin_audit_entities.dart';

class MockApiClient extends Mock implements ApiClient {}

/// B5 contract shapes (`GET /api/admin-audit`, `/:id`, `/facets`).
Map<String, dynamic> listItem({int id = 1, Object? summary, String? actorName = 'Ana'}) => {
      'id': id,
      'actorId': 4,
      'actorName': actorName,
      'action': 'update',
      'entity': 'user',
      'entityId': '12',
      'summary': summary,
      'createdAt': '2026-09-02T10:00:00.000Z',
    };

Map<String, dynamic> page(List<Map<String, dynamic>> items) =>
    {'items': items, 'page': 1, 'pageSize': 50, 'total': items.length};

void main() {
  late MockApiClient apiClient;
  late AdminAuditRepositoryImpl repository;

  setUp(() {
    apiClient = MockApiClient();
    repository = AdminAuditRepositoryImpl(apiClient);
  });

  group('list — query string', () {
    test('no filter sends only page and pageSize', () async {
      when(() => apiClient.get(any())).thenAnswer((_) async => page([]));

      await repository.list(const AuditFiltersEntity(), 1, 50);

      final path = verify(() => apiClient.get(captureAny())).captured.single as String;
      final uri = Uri.parse(path);
      expect(uri.path, '/api/admin-audit');
      expect(uri.queryParameters, {'page': '1', 'pageSize': '50'});
    });

    test('every filter travels under the contract name', () async {
      when(() => apiClient.get(any())).thenAnswer((_) async => page([]));

      await repository.list(
        const AuditFiltersEntity(
          actorId: 4,
          action: 'grant',
          entity: 'user_privileges',
          entityId: '12',
          from: '2026-09-01',
          to: '2026-09-02',
        ),
        2,
        25,
      );

      final path = verify(() => apiClient.get(captureAny())).captured.single as String;
      expect(Uri.parse(path).queryParameters, {
        'page': '2',
        'pageSize': '25',
        'actorId': '4',
        'action': 'grant',
        'entity': 'user_privileges',
        'entityId': '12',
        'from': '2026-09-01',
        'to': '2026-09-02',
      });
    });
  });

  group('list — mapping', () {
    test('rows map who/what/when; summary object, string and null are kept as served', () async {
      when(() => apiClient.get(any())).thenAnswer((_) async => page([
            listItem(id: 1, summary: {'name': 'Ana'}),
            listItem(id: 2, summary: 'raw text'),
            listItem(id: 3, summary: null, actorName: null),
          ]));

      final result = await repository.list(const AuditFiltersEntity(), 1, 50);

      final loaded = result.getOrElse(() => throw StateError('left'));
      expect(loaded.total, 3);
      expect(loaded.items.map((e) => e.id), [1, 2, 3]);
      expect(loaded.items[0].summary, {'name': 'Ana'});
      expect(loaded.items[0].actorName, 'Ana');
      expect(loaded.items[0].entityId, '12');
      expect(loaded.items[1].summary, 'raw text');
      expect(loaded.items[2].summary, isNull);
      // A deleted panel user keeps the row; only the name is gone.
      expect(loaded.items[2].actorName, isNull);
      expect(loaded.items[2].actorId, 4);
    });

    test('the list entity has no ip — personal data lives on the detail only', () async {
      // Even if a payload carried it, the list shape cannot hold it.
      when(() => apiClient.get(any())).thenAnswer((_) async => page([
            listItem()..['ip'] = '10.0.0.1',
          ]));

      final result = await repository.list(const AuditFiltersEntity(), 1, 50);

      final item = result.getOrElse(() => throw StateError('left')).items.single;
      expect(item, isA<AuditListItemEntity>());
      expect(item, isNot(isA<AuditEntryEntity>()));
      expect(item.props, isNot(contains('10.0.0.1')));
    });

    test('a 422 (bad filter, decision 83) is Left with the code intact', () async {
      when(() => apiClient.get(any())).thenThrow(
          const Failure(message: 'bad', statusCode: 422, code: 'VALIDATION_FAILED'));

      final result = await repository.list(const AuditFiltersEntity(from: 'x'), 1, 50);

      expect(result.fold((f) => f.code, (_) => null), 'VALIDATION_FAILED');
    });
  });

  group('get', () {
    test('reads /api/admin-audit/:id and maps the entry with its ip', () async {
      when(() => apiClient.get('/api/admin-audit/7'))
          .thenAnswer((_) async => listItem(id: 7, summary: {'a': 1})..['ip'] = '10.0.0.1');

      final result = await repository.get(7);

      final entry = result.getOrElse(() => throw StateError('left'));
      expect(entry, isA<AuditEntryEntity>());
      expect(entry.id, 7);
      expect(entry.ip, '10.0.0.1');
      expect(entry.summary, {'a': 1});
    });

    test('a null ip stays null', () async {
      when(() => apiClient.get('/api/admin-audit/7'))
          .thenAnswer((_) async => listItem(id: 7)..['ip'] = null);

      final result = await repository.get(7);

      expect(result.getOrElse(() => throw StateError('left')).ip, isNull);
    });

    test('a 404 is Left with the code intact', () async {
      when(() => apiClient.get('/api/admin-audit/9')).thenThrow(
          const Failure(message: 'gone', statusCode: 404, code: 'NOT_FOUND'));

      final result = await repository.get(9);

      expect(result.fold((f) => f.code, (_) => null), 'NOT_FOUND');
    });
  });

  group('facets', () {
    test('reads /api/admin-audit/facets and maps both lists', () async {
      when(() => apiClient.get('/api/admin-audit/facets')).thenAnswer((_) async => {
            'actions': ['create', 'read'],
            'entities': ['user', 'report'],
          });

      final result = await repository.facets();

      expect(result.getOrElse(() => throw StateError('left')),
          const AuditFacetsEntity(actions: ['create', 'read'], entities: ['user', 'report']));
    });

    test('a refusal is Left', () async {
      when(() => apiClient.get('/api/admin-audit/facets')).thenThrow(
          const Failure(message: 'no', statusCode: 403, code: 'FORBIDDEN'));

      final result = await repository.facets();

      expect(result.isLeft(), isTrue);
    });
  });
}
