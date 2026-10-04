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
import 'package:vgr_admin/app/shared/feedback/feedback.dart';
import 'package:vgr_admin/app/shared/register/register_search_page.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../../helpers/pump_localized.dart';
import '../../../../helpers/session_access.dart';

class MockPrivilegeRepository extends Mock implements PrivilegeRepository {}

/// The privilege catalog on the register factory (PS2 pilot).
void main() {
  late MockPrivilegeRepository repository;

  const view = PrivilegeEntity(id: 1, description: 'VIEW');
  const print = PrivilegeEntity(id: 5, description: 'PRINT');

  setUpAll(() {
    registerFallbackValue(const PagedQuery());
    registerFallbackValue(const PrivilegeDraft(''));
    registerFallbackValue(view);
  });

  setUp(() {
    repository = MockPrivilegeRepository();
    when(() => repository.list(any())).thenAnswer(
      (_) async => const Right(PagedResult(items: [view, print], page: 1, pageSize: 20, total: 2)),
    );
  });

  tearDown(revokeAllPrivileges);

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpLocalized(
      tester,
      BlocProvider<PrivilegeBloc>(
        create: (_) => PrivilegeBloc(repository)..add(const RegisterListRequested()),
        child: const PrivilegePage(),
      ),
    );
  }

  final descriptionField = find.byKey(const Key('register-field-description'));

  testWidgets('lists the catalog with translated names and the identifier as subtitle', (tester) async {
    grantAllPrivileges();

    await pumpPage(tester);

    expect(find.text('View'), findsOneWidget);
    expect(find.text('VIEW'), findsOneWidget);
    expect(find.text('Print'), findsOneWidget);
    expect(find.byKey(RegisterSearchPage.newButtonKey), findsOneWidget);
    verify(() => repository.list(const PagedQuery())).called(1);
  });

  testWidgets('without INSERT there is no new button; a row opens read-only', (tester) async {
    revokeAllPrivileges();

    await pumpPage(tester);
    expect(find.byKey(RegisterSearchPage.newButtonKey), findsNothing);

    await tester.tap(find.byKey(RegisterSearchPage.rowKey(5)));
    await tester.pumpAndSettle();
    expect(find.byKey(VgrFormShell.saveKey), findsNothing);
    expect(find.byKey(VgrFormShell.deleteKey), findsNothing);
  });

  testWidgets('a lowercase identifier is caught before the round trip (privilegeSaveDto)', (tester) async {
    grantAllPrivileges();
    await pumpPage(tester);

    await tester.tap(find.byKey(RegisterSearchPage.newButtonKey));
    await tester.pumpAndSettle();
    await tester.enterText(descriptionField, 'export');
    await tester.tap(find.byKey(VgrFormShell.saveKey));
    await tester.pumpAndSettle();

    expect(find.text('Identifier (UPPER_SNAKE_CASE): Invalid format.'), findsOneWidget);
    verifyNever(() => repository.create(any()));
  });

  testWidgets('a valid new identifier is created and the list refreshed', (tester) async {
    grantAllPrivileges();
    when(() => repository.create(const PrivilegeDraft('EXPORT')))
        .thenAnswer((_) async => const Right(PrivilegeEntity(id: 6, description: 'EXPORT')));
    await pumpPage(tester);

    await tester.tap(find.byKey(RegisterSearchPage.newButtonKey));
    await tester.pumpAndSettle();
    expect(find.text('New privilege'), findsOneWidget);
    await tester.enterText(descriptionField, 'EXPORT');
    await tester.tap(find.byKey(VgrFormShell.saveKey));
    await tester.pumpAndSettle();

    verify(() => repository.create(const PrivilegeDraft('EXPORT'))).called(1);
    expect(find.text('Record saved.'), findsOneWidget);
    verify(() => repository.list(const PagedQuery())).called(2);
  });

  testWidgets('a refused delete keeps the form and surfaces the code-translated error', (tester) async {
    grantAllPrivileges();
    when(() => repository.delete(print)).thenAnswer(
      (_) async => const Left(Failure(
        message: 'Privilege is in use by interfaces or user grants',
        statusCode: 409,
        code: 'IN_USE',
      )),
    );

    await pumpPage(tester);
    await tester.tap(find.byKey(RegisterSearchPage.rowKey(5)));
    await tester.pumpAndSettle();
    expect(find.text('Privilege PRINT'), findsOneWidget);

    await tester.tap(find.byKey(VgrFormShell.deleteKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(decisionYesKey));
    await tester.pumpAndSettle();

    // Translated by core.errors.IN_USE (decisions 80/83), not the raw API text.
    expect(find.text('This record is in use and cannot be deleted.'), findsOneWidget);
    expect(find.text('Privilege PRINT'), findsOneWidget);
  });
}
