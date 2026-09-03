import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/admin-audit/domain/entity/admin_audit_entities.dart';
import 'package:vgr_admin/app/modules/admin-audit/domain/repository/admin_audit_repository.dart';
import 'package:vgr_admin/app/modules/admin-audit/presentation/bloc/admin_audit_list_bloc.dart';
import 'package:vgr_admin/app/modules/admin-audit/presentation/bloc/admin_audit_list_event.dart';
import 'package:vgr_admin/app/modules/admin-audit/presentation/bloc/admin_audit_list_state.dart';

class MockAdminAuditRepository extends Mock implements AdminAuditRepository {}

const _none = AuditFiltersEntity();
const _grants = AuditFiltersEntity(action: 'grant');
const _facets = AuditFacetsEntity(actions: ['grant', 'update'], entities: ['user']);
const _empty = AuditPageEntity(items: [], page: 1, pageSize: 50, total: 0);
const _page2 = AuditPageEntity(items: [], page: 2, pageSize: 50, total: 80);

/// B5: facets + first page on entry, filters → page 1, prev/next under the
/// same filters. Nothing here is audited (166) and nothing is cached.
void main() {
  late MockAdminAuditRepository repository;

  setUp(() {
    repository = MockAdminAuditRepository();
    registerFallbackValue(_none);
    when(() => repository.facets()).thenAnswer((_) async => const Right(_facets));
  });

  AdminAuditListBloc build() => AdminAuditListBloc(repository);

  test('starts idle; nothing is read before Started', () {
    expect(build().state, const AdminAuditListInitial());
    verifyNever(() => repository.list(any(), any(), any()));
    verifyNever(() => repository.facets());
  });

  test('Started loads facets and the first page without filters', () async {
    when(() => repository.list(_none, 1, 50)).thenAnswer((_) async => const Right(_empty));

    final bloc = build();
    expect(
      bloc.stream,
      emitsInOrder([
        const AdminAuditListLoading(_none, null),
        const AdminAuditListLoaded(_empty, _none, _facets),
      ]),
    );

    bloc.add(const AdminAuditListStarted());
  });

  test('a facets refusal leaves the dropdowns empty but still serves the list', () async {
    when(() => repository.facets()).thenAnswer((_) async =>
        const Left(Failure(message: 'no', statusCode: 500, code: 'INTERNAL')));
    when(() => repository.list(_none, 1, 50)).thenAnswer((_) async => const Right(_empty));

    final bloc = build()..add(const AdminAuditListStarted());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state, const AdminAuditListLoaded(_empty, _none, AuditFacetsEntity.empty));
  });

  test('Search re-reads page 1 under the new filters, keeping the facets', () async {
    when(() => repository.list(_none, 1, 50)).thenAnswer((_) async => const Right(_empty));
    when(() => repository.list(_grants, 1, 50)).thenAnswer((_) async => const Right(_empty));
    final bloc = build()..add(const AdminAuditListStarted());
    await Future<void>.delayed(Duration.zero);

    bloc.add(const AdminAuditSearchRequested(_grants));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state, const AdminAuditListLoaded(_empty, _grants, _facets));
    verify(() => repository.list(_grants, 1, 50)).called(1);
    verify(() => repository.facets()).called(1);
  });

  test('PageRequested reads that page under the CURRENT filters', () async {
    when(() => repository.list(_none, 1, 50)).thenAnswer((_) async => const Right(_empty));
    when(() => repository.list(_grants, 1, 50)).thenAnswer((_) async => const Right(_empty));
    when(() => repository.list(_grants, 2, 50)).thenAnswer((_) async => const Right(_page2));
    final bloc = build()..add(const AdminAuditListStarted());
    await Future<void>.delayed(Duration.zero);
    bloc.add(const AdminAuditSearchRequested(_grants));
    await Future<void>.delayed(Duration.zero);

    bloc.add(const AdminAuditPageRequested(2));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state, const AdminAuditListLoaded(_page2, _grants, _facets));
  });

  test('PageRequested before any load is a no-op', () async {
    final bloc = build()..add(const AdminAuditPageRequested(2));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state, const AdminAuditListInitial());
    verifyNever(() => repository.list(any(), any(), any()));
  });

  test('a list refusal (403 without the grant, 422 bad filter) is an error keeping filters '
      'and facets', () async {
    const failure = Failure(message: 'no', statusCode: 403, code: 'FORBIDDEN');
    when(() => repository.list(_none, 1, 50)).thenAnswer((_) async => const Left(failure));

    final bloc = build()..add(const AdminAuditListStarted());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state, const AdminAuditListError(failure, _none, _facets));
  });
}
