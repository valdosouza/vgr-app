import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/home/presentation/home_page.dart';

import '../../../helpers/pump_localized.dart';

class MockMenuRepository extends Mock implements MenuRepository {}

void main() {
  late MockMenuRepository repository;

  setUp(() {
    repository = MockMenuRepository();
    SessionAccess.instance.clear();
    // Decision 93: the bloc also fetches the full grant map; an empty Left
    // keeps SessionAccess fed by the tree fallback in these tests.
    when(() => repository.getPermissions())
        .thenAnswer((_) async => const Left(Failure(message: 'offline')));
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await pumpLocalized(
      tester,
      BlocProvider(
        create: (_) => MenuBloc(repository)..add(const MenuRequested()),
        child: const HomePage(),
      ),
    );
  }

  testWidgets('renders the backend menu tree grouped by module, with translated labels', (tester) async {
    when(() => repository.getMenus()).thenAnswer(
      (_) async => const Right([
        MenuModule(id: null, description: 'Operations', interfaces: [
          MenuInterface(id: 1, description: 'Risk Tier Configuration', i18nKey: 'risk_config', privileges: ['VIEW']),
          MenuInterface(id: 5, description: 'Monetization Config', i18nKey: 'monetization_config', privileges: ['VIEW']),
        ]),
        MenuModule(id: null, description: 'Administration', interfaces: [
          MenuInterface(id: 6, description: 'Users', i18nKey: 'users', privileges: ['VIEW', 'UPDATE']),
        ]),
      ]),
    );

    await pumpHome(tester);

    // Group labels come from menu.groups.*, screens from menu.interfaces.*.
    expect(find.text('Operations'), findsOneWidget);
    expect(find.text('Administration'), findsOneWidget);
    expect(find.text('Risk Config'), findsOneWidget);
    expect(find.text('Monetization Config'), findsOneWidget);
    expect(find.text('Users'), findsOneWidget);
  });

  testWidgets('loading the menu feeds SessionAccess (can() reflects the grants)', (tester) async {
    when(() => repository.getMenus()).thenAnswer(
      (_) async => const Right([
        MenuModule(id: null, description: 'Operations', interfaces: [
          MenuInterface(id: 1, description: 'Risk', i18nKey: 'risk_config', privileges: ['VIEW', 'UPDATE']),
        ]),
      ]),
    );

    await pumpHome(tester);

    expect(SessionAccess.instance.can('risk_config', Privileges.update), isTrue);
    expect(SessionAccess.instance.can('risk_config', Privileges.delete), isFalse);
    expect(SessionAccess.instance.can('users', Privileges.view), isFalse);
  });

  testWidgets('a user with zero grants sees the empty-menu message', (tester) async {
    when(() => repository.getMenus()).thenAnswer((_) async => const Right([]));

    await pumpHome(tester);

    expect(find.text('No screens available for your user — ask an Admin for access.'), findsOneWidget);
  });

  testWidgets('a menu load failure shows the message with a retry button', (tester) async {
    when(() => repository.getMenus()).thenAnswer(
      (_) async => const Left(Failure(message: 'Internal error', statusCode: 500)),
    );

    await pumpHome(tester);

    expect(find.text('Internal error'), findsOneWidget);
    expect(find.byKey(const Key('menu-retry-button')), findsOneWidget);
  });

  testWidgets('the permissions map feeds SessionAccess with kind-R resources absent from the menu (decision 93)', (tester) async {
    when(() => repository.getMenus()).thenAnswer((_) async => const Right([]));
    when(() => repository.getPermissions()).thenAnswer(
      (_) async => const Right({
        'users': ['VIEW', 'UPDATE'],
        'user_privileges': ['VIEW', 'UPDATE'],
      }),
    );

    await pumpHome(tester);

    // The R resource never appears on the (empty) menu, yet can() knows it.
    expect(SessionAccess.instance.can('user_privileges', Privileges.update), isTrue);
    expect(SessionAccess.instance.can('users', Privileges.view), isTrue);
    expect(SessionAccess.instance.can('privileges', Privileges.view), isFalse);
  });
}
