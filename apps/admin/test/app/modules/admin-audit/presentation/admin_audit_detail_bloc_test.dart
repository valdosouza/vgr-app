import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/admin-audit/domain/entity/admin_audit_entities.dart';
import 'package:vgr_admin/app/modules/admin-audit/domain/repository/admin_audit_repository.dart';
import 'package:vgr_admin/app/modules/admin-audit/presentation/bloc/admin_audit_detail_bloc.dart';
import 'package:vgr_admin/app/modules/admin-audit/presentation/bloc/admin_audit_detail_event.dart';
import 'package:vgr_admin/app/modules/admin-audit/presentation/bloc/admin_audit_detail_state.dart';

class MockAdminAuditRepository extends Mock implements AdminAuditRepository {}

const _entry = AuditEntryEntity(
  id: 7,
  actorId: 4,
  actorName: 'Ana',
  action: 'grant',
  entity: 'user_privileges',
  entityId: '12',
  summary: {'granted': 'reports'},
  createdAt: '2026-09-02T10:00:00.000Z',
  ip: '10.0.0.1',
);

/// B5: ONE read of ONE entry — the only place the operator `ip` is served.
void main() {
  late MockAdminAuditRepository repository;

  setUp(() {
    repository = MockAdminAuditRepository();
  });

  test('starts idle', () {
    expect(AdminAuditDetailBloc(repository).state, const AdminAuditDetailInitial());
    verifyNever(() => repository.get(any()));
  });

  test('a request emits loading then loaded with the entry', () {
    when(() => repository.get(7)).thenAnswer((_) async => const Right(_entry));

    final bloc = AdminAuditDetailBloc(repository);
    expect(
      bloc.stream,
      emitsInOrder([
        const AdminAuditDetailLoading(),
        const AdminAuditDetailLoaded(_entry),
      ]),
    );

    bloc.add(const AdminAuditDetailRequested(7));
  });

  test('a 404 is an error state', () async {
    const failure = Failure(message: 'gone', statusCode: 404, code: 'NOT_FOUND');
    when(() => repository.get(9)).thenAnswer((_) async => const Left(failure));

    final bloc = AdminAuditDetailBloc(repository)..add(const AdminAuditDetailRequested(9));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state, const AdminAuditDetailError(failure));
  });
}
