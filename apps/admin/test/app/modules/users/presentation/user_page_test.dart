import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/users/domain/entity/user_entity.dart';
import 'package:vgr_admin/app/modules/users/domain/repository/user_repository.dart';
import 'package:vgr_admin/app/modules/users/presentation/bloc/user_bloc.dart';
import 'package:vgr_admin/app/modules/users/presentation/page/user_page.dart';
import 'package:vgr_admin/app/shared/feedback/feedback.dart';
import 'package:vgr_admin/app/shared/register/register_search_page.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../../helpers/pump_localized.dart';
import '../../../../helpers/session_access.dart';

class MockUserRepository extends Mock implements UserRepository {}

/// Team users on the register factory (PS2 pilot): the form left the
/// dialog, validates like userCreateDto / userUpdateDto, and the lockout
/// refusal comes back through the bridge.
void main() {
  late MockUserRepository repository;

  const ana = UserEntity(id: 2, name: 'Ana', email: 'ana@vgr.com.br');
  const me = UserEntity(id: 1, name: 'Valdo', email: 'valdo@vgr.com.br');

  setUpAll(() {
    registerFallbackValue(const PagedQuery());
    registerFallbackValue(const UserDraft(name: '', email: '', active: 'S'));
    registerFallbackValue(ana);
  });

  setUp(() {
    repository = MockUserRepository();
    when(() => repository.list(any())).thenAnswer(
      (_) async => const Right(PagedResult(items: [me, ana], page: 1, pageSize: 20, total: 2)),
    );
    grantAllPrivileges();
  });

  tearDown(revokeAllPrivileges);

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpLocalized(
      tester,
      BlocProvider<UserBloc>(
        create: (_) => UserBloc(repository)..add(const RegisterListRequested()),
        child: const UserPage(),
      ),
    );
  }

  Finder field(String name) => find.byKey(Key('register-field-$name'));

  testWidgets('the form opens inside the screen, not in a dialog', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(RegisterSearchPage.newButtonKey));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('New user'), findsOneWidget);
    expect(field('name'), findsOneWidget);
    expect(field('active'), findsOneWidget);
    expect(find.text('12 to 72 characters'), findsOneWidget);
  });

  testWidgets('creating requires the initial password (newPasswordSchema)', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(RegisterSearchPage.newButtonKey));
    await tester.pumpAndSettle();

    await tester.enterText(field('name'), 'Bia');
    await tester.enterText(field('email'), 'bia@vgr.com.br');
    await tester.tap(find.byKey(VgrFormShell.saveKey));
    await tester.pumpAndSettle();

    expect(find.text('Password: Required field.'), findsOneWidget);
    await tester.tap(find.byKey(feedbackCloseKey));
    await tester.pumpAndSettle();

    await tester.enterText(field('password'), 'short');
    await tester.tap(find.byKey(VgrFormShell.saveKey));
    await tester.pumpAndSettle();
    expect(find.text('Password: Minimum of 12 characters.'), findsOneWidget);
    verifyNever(() => repository.create(any()));
  });

  testWidgets('a valid new user is created with the trimmed name and e-mail', (tester) async {
    when(() => repository.create(any()))
        .thenAnswer((_) async => const Right(UserEntity(id: 3, name: 'Bia', email: 'bia@vgr.com.br')));
    await pumpPage(tester);
    await tester.tap(find.byKey(RegisterSearchPage.newButtonKey));
    await tester.pumpAndSettle();

    await tester.enterText(field('name'), ' Bia ');
    await tester.enterText(field('email'), 'bia@vgr.com.br ');
    await tester.enterText(field('password'), 'a long password');
    await tester.tap(find.byKey(VgrFormShell.saveKey));
    await tester.pumpAndSettle();

    verify(() => repository.create(const UserDraft(
          name: 'Bia',
          email: 'bia@vgr.com.br',
          active: 'S',
          password: 'a long password',
        ))).called(1);
    expect(find.text('Record saved.'), findsOneWidget);
  });

  testWidgets('editing with the password left empty keeps the current one', (tester) async {
    when(() => repository.update(any(), any())).thenAnswer((_) async => const Right(ana));
    await pumpPage(tester);
    await tester.tap(find.byKey(RegisterSearchPage.rowKey(2)));
    await tester.pumpAndSettle();

    expect(find.text('User — Ana'), findsOneWidget);
    expect(find.text('Leave empty to keep the current password'), findsOneWidget);
    await tester.tap(field('active'));
    await tester.pump();
    await tester.tap(find.byKey(VgrFormShell.saveKey));
    await tester.pumpAndSettle();

    verify(() => repository.update(ana, const UserDraft(name: 'Ana', email: 'ana@vgr.com.br', active: 'N')))
        .called(1);
  });

  testWidgets('an e-mail the API refuses (422 fields[]) lands on the e-mail field', (tester) async {
    when(() => repository.update(any(), any())).thenAnswer((_) async => const Left(Failure(
          message: 'Validation failed',
          statusCode: 422,
          code: 'VALIDATION_FAILED',
          fields: [FieldFailure(field: 'email', message: 'Invalid email', code: 'INVALID_EMAIL')],
        )));
    await pumpPage(tester);
    await tester.tap(find.byKey(RegisterSearchPage.rowKey(2)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(VgrFormShell.saveKey));
    await tester.pumpAndSettle();

    expect(find.text('Email: Invalid email.'), findsOneWidget);
  });

  testWidgets('deleting your own account: SELF_LOCKOUT comes back through the bridge', (tester) async {
    when(() => repository.delete(me)).thenAnswer((_) async => const Left(Failure(
          message: 'You cannot delete your own account',
          statusCode: 409,
          code: 'SELF_LOCKOUT',
        )));
    await pumpPage(tester);
    await tester.tap(find.byKey(RegisterSearchPage.rowKey(1)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(VgrFormShell.deleteKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(decisionYesKey));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('User — Valdo'), findsOneWidget); // still on the form
  });

  testWidgets('with the user_privileges grant each row offers the privilege matrix', (tester) async {
    await pumpPage(tester);
    expect(find.byKey(const Key('user-privileges-2')), findsOneWidget);
  });

  testWidgets('without the user_privileges grant (decision 93) the matrix button is absent', (tester) async {
    SessionAccess.instance.applyPermissions(const {
      'users': [Privileges.view],
    });
    await pumpPage(tester);
    expect(find.byKey(RegisterSearchPage.rowKey(2)), findsOneWidget);
    expect(find.byKey(const Key('user-privileges-2')), findsNothing);
  });
}
