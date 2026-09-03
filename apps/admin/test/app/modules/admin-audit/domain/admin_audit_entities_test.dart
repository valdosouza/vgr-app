import 'package:flutter_test/flutter_test.dart';
import 'package:vgr_admin/app/modules/admin-audit/domain/entity/admin_audit_entities.dart';

/// B5 (decisions 116/158/165/166): the trail is READ only on the panel.
void main() {
  group('AuditFiltersEntity.toQueryParameters', () {
    test('omits every unset filter', () {
      expect(const AuditFiltersEntity().toQueryParameters(), isEmpty);
    });

    test('emits each filter under the contract name', () {
      const filters = AuditFiltersEntity(
        actorId: 4,
        action: 'grant',
        entity: 'user_privileges',
        entityId: '12',
        from: '2026-09-01',
        to: '2026-09-02',
      );

      expect(filters.toQueryParameters(), {
        'actorId': '4',
        'action': 'grant',
        'entity': 'user_privileges',
        'entityId': '12',
        'from': '2026-09-01',
        'to': '2026-09-02',
      });
    });
  });

  group('AuditListItemEntity.summaryPreview', () {
    AuditListItemEntity item(Object? summary) => AuditListItemEntity(
          id: 1,
          actorId: 4,
          actorName: 'Ana',
          action: 'update',
          entity: 'user',
          entityId: '12',
          summary: summary,
          createdAt: '2026-09-02T10:00:00.000Z',
        );

    test('a JSON object becomes one compact line', () {
      expect(item({'name': 'Ana', 'active': true}).summaryPreview(),
          '{"name":"Ana","active":true}');
    });

    test('a string is collapsed to one line and truncated with an ellipsis', () {
      final preview = item('line one\nline two ${'x' * 200}').summaryPreview(max: 20);

      expect(preview, hasLength(20));
      expect(preview, startsWith('line one line two'));
      expect(preview, endsWith('…'));
    });

    test('null is an empty preview', () {
      expect(item(null).summaryPreview(), '');
    });
  });

  test('AuditPageEntity.pageCount rounds up and never drops below 1', () {
    const empty = AuditPageEntity(items: [], page: 1, pageSize: 50, total: 0);
    const some = AuditPageEntity(items: [], page: 1, pageSize: 50, total: 101);

    expect(empty.pageCount, 1);
    expect(some.pageCount, 3);
  });
}
