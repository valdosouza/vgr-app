import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/admin-audit/domain/entity/admin_audit_entities.dart';
import 'package:vgr_admin/app/modules/admin-audit/domain/repository/admin_audit_repository.dart';
import 'package:vgr_admin/app/modules/admin-audit/presentation/bloc/admin_audit_detail_bloc.dart';
import 'package:vgr_admin/app/modules/admin-audit/presentation/page/admin_audit_detail_page.dart';

import '../../../../helpers/pump_localized.dart';
import '../../../../helpers/session_access.dart';

class MockAdminAuditRepository extends Mock implements AdminAuditRepository {}

AuditEntryEntity entry({Object? summary, String? ip = '10.0.0.1', String? actorName = 'Ana'}) =>
    AuditEntryEntity(
      id: 7,
      actorId: 4,
      actorName: actorName,
      action: 'grant',
      entity: 'user_privileges',
      entityId: '12',
      summary: summary,
      createdAt: '2026-09-02T10:00:00.000Z',
      ip: ip,
    );

/// B5: the detail is the ONLY place the operator `ip` is shown, with its
/// privacy caption; `summary` is rendered as text/tree, never executed.
void main() {
  late MockAdminAuditRepository repository;

  setUp(() {
    grantAllPrivileges();
    repository = MockAdminAuditRepository();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await pumpLocalized(
      tester,
      BlocProvider(
        create: (_) => AdminAuditDetailBloc(repository),
        child: const AdminAuditDetailPage(entryId: 7),
      ),
    );
  }

  testWidgets('who · what · when, target, and a JSON-object summary as a key/value list with '
      'nested values as indented text', (tester) async {
    when(() => repository.get(7)).thenAnswer((_) async => Right(entry(summary: {
          'granted': 'reports',
          'before': {'active': true},
        })));
    await pumpPage(tester);

    expect(find.byKey(const Key('audit-detail-7')), findsOneWidget);
    expect(find.text('Ana (#4)'), findsOneWidget);
    expect(find.text('Grant'), findsOneWidget);
    expect(find.text('user_privileges#12'), findsOneWidget);
    expect(find.text('2026-09-02 10:00'), findsOneWidget);
    expect(find.byKey(const Key('audit-summary-granted')), findsOneWidget);
    expect(find.text('reports'), findsOneWidget);
    expect(find.byKey(const Key('audit-summary-before')), findsOneWidget);
    expect(find.text('{\n  "active": true\n}'), findsOneWidget);
    expect(find.byKey(const Key('audit-summary-text')), findsNothing);
  });

  testWidgets('a string summary renders as text', (tester) async {
    when(() => repository.get(7)).thenAnswer((_) async => Right(entry(summary: 'raw text')));
    await pumpPage(tester);

    expect(find.byKey(const Key('audit-summary-text')), findsOneWidget);
    expect(find.text('raw text'), findsOneWidget);
  });

  testWidgets('a missing summary says so', (tester) async {
    when(() => repository.get(7)).thenAnswer((_) async => Right(entry(summary: null)));
    await pumpPage(tester);

    expect(find.text('No summary recorded.'), findsOneWidget);
  });

  testWidgets('the ip is shown with the personal-data caption; a deleted actor keeps the id',
      (tester) async {
    when(() => repository.get(7)).thenAnswer((_) async => Right(entry(actorName: null)));
    await pumpPage(tester);

    expect(find.text('10.0.0.1'), findsOneWidget);
    expect(find.byKey(const Key('audit-ip-caption')), findsOneWidget);
    expect(find.textContaining('Personal data'), findsOneWidget);
    expect(find.text('Unknown user (#4)'), findsOneWidget);
    expect(find.byKey(const Key('audit-back')), findsOneWidget);
  });

  testWidgets('a null ip renders as a dash, caption kept', (tester) async {
    when(() => repository.get(7)).thenAnswer((_) async => Right(entry(ip: null)));
    await pumpPage(tester);

    expect(find.byKey(const Key('audit-ip')), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.byKey(const Key('audit-ip-caption')), findsOneWidget);
  });

  testWidgets('a 404 renders the lookup error translated by code', (tester) async {
    when(() => repository.get(7)).thenAnswer((_) async =>
        const Left(Failure(message: 'gone', statusCode: 404, code: 'NOT_FOUND')));
    await pumpPage(tester);

    expect(find.byKey(const Key('audit-detail-error')), findsOneWidget);
    expect(find.text('Record not found.'), findsOneWidget);
  });
}
