import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/privileges/domain/entity/privilege_entity.dart';
import 'package:vgr_admin/app/modules/privileges/domain/repository/privilege_repository.dart';
import 'package:vgr_admin/app/modules/privileges/presentation/bloc/privilege_bloc.dart';
import 'package:vgr_admin/app/modules/privileges/presentation/page/privilege_page.dart';

import '../../../../helpers/pump_localized.dart';
import '../../../../helpers/session_access.dart';

class MockPrivilegeRepository extends Mock implements PrivilegeRepository {}

void main() {
  late MockPrivilegeRepository repository;

  const catalog = [
    PrivilegeEntity(id: 1, description: 'VIEW'),
    PrivilegeEntity(id: 5, description: 'PRINT'),
  ];

  setUp(() {
    repository = MockPrivilegeRepository();
    when(() => repository.list()).thenAnswer((_) async => const Right(catalog));
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await pumpLocalized(
      tester,
      BlocProvider(
        create: (_) => PrivilegeBloc(repository)..add(const PrivilegeFetchRequested()),
        child: const PrivilegePage(),
      ),
    );
  }

  testWidgets('lists the catalog with translated names and the identifier as subtitle', (tester) async {
    grantAllPrivileges();

    await pumpPage(tester);

    expect(find.text('View'), findsOneWidget);
    expect(find.text('VIEW'), findsOneWidget);
    expect(find.text('Print'), findsOneWidget);
    expect(find.byKey(const Key('privilege-new-button')), findsOneWidget);
  });

  testWidgets('without INSERT/DELETE grants the FAB and delete icons do not render', (tester) async {
    revokeAllPrivileges();

    await pumpPage(tester);

    expect(find.byKey(const Key('privilege-new-button')), findsNothing);
    expect(find.byKey(const Key('privilege-delete-1')), findsNothing);
  });

  testWidgets('a failed delete keeps the list and surfaces the code-translated error', (tester) async {
    grantAllPrivileges();
    when(() => repository.delete(5)).thenAnswer(
      (_) async => const Left(Failure(
        message: 'Privilege is in use by interfaces or user grants',
        statusCode: 409,
        code: 'IN_USE',
      )),
    );

    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('privilege-delete-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('privilege-confirm-delete-button')));
    await tester.pumpAndSettle();

    // Translated by core.errors.IN_USE (decision 80/83), not the raw API text.
    expect(find.text('This record is in use and cannot be deleted.'), findsOneWidget);
    expect(find.text('Print'), findsOneWidget);
  });
}
