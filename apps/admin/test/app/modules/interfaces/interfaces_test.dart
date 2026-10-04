import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/interfaces/data/interface_repository_impl.dart';
import 'package:vgr_admin/app/modules/interfaces/domain/entity/interface_entity.dart';
import 'package:vgr_admin/app/modules/interfaces/domain/repository/interface_repository.dart';
import 'package:vgr_admin/app/modules/interfaces/presentation/bloc/interface_bloc.dart';
import 'package:vgr_admin/app/modules/interfaces/presentation/page/interface_page.dart';
import 'package:vgr_admin/app/shared/register/register_search_page.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../helpers/pump_localized.dart';
import '../../../helpers/session_access.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockInterfaceRepository extends Mock implements InterfaceRepository {}

/// The screen catalog on the register factory (PS3).
void main() {
  const users = InterfaceEntity(
    id: 4,
    description: 'Users',
    i18nKey: 'users',
    groupDefault: 'Access',
    position: 2,
    privilegeIds: [1, 3],
  );

  group('repository', () {
    late MockApiClient apiClient;
    late InterfaceRepositoryImpl repository;

    setUp(() {
      apiClient = MockApiClient();
      repository = InterfaceRepositoryImpl(apiClient);
    });

    test('the list is paged (PS0); the privilege options are the unpaged catalog', () async {
      when(() => apiClient.get('/api/interfaces?page=1&pageSize=20&filter=user')).thenAnswer(
        (_) async => {
          'ok': true,
          'data': {
            'items': [
              {'id': 4, 'description': 'Users', 'i18nKey': 'users', 'groupDefault': 'Access'},
            ],
            'page': 1,
            'pageSize': 20,
            'total': 1,
          },
        },
      );
      when(() => apiClient.get('/api/privileges')).thenAnswer(
        (_) async => {
          'ok': true,
          'data': [
            {'id': 1, 'description': 'VIEW'},
          ],
        },
      );

      final page = await repository.list(const PagedQuery(filter: 'user'));
      final options = await repository.listPrivilegeOptions();

      page.fold((f) => fail('$f'), (page) => expect(page.items.single.i18nKey, 'users'));
      options.fold((f) => fail('$f'), (list) => expect(list, const [PrivilegeOption(id: 1, description: 'VIEW')]));
    });

    test('update sends the draft to the row it was opened on', () async {
      const draft = InterfaceDraft(
        description: 'Users',
        i18nKey: 'users',
        groupDefault: 'Access',
        kind: 'T',
        position: 2,
        privilegeIds: [1],
      );
      when(() => apiClient.put('/api/interfaces/4', draft.toJson())).thenAnswer(
        (_) async => {
          'ok': true,
          'data': {'id': 4, 'description': 'Users', 'i18nKey': 'users', 'groupDefault': 'Access'},
        },
      );

      final result = await repository.update(users, draft);

      expect(result.isRight(), isTrue);
    });
  });

  group('page', () {
    late MockInterfaceRepository repository;

    setUpAll(() {
      registerFallbackValue(const PagedQuery());
      registerFallbackValue(const InterfaceDraft(
        description: '',
        i18nKey: '',
        groupDefault: '',
        kind: 'T',
        position: 0,
        privilegeIds: [],
      ));
      registerFallbackValue(users);
    });

    setUp(() {
      repository = MockInterfaceRepository();
      when(() => repository.list(any())).thenAnswer(
        (_) async => const Right(PagedResult(items: [users], page: 1, pageSize: 20, total: 1)),
      );
      when(() => repository.listPrivilegeOptions()).thenAnswer(
        (_) async => const Right([
          PrivilegeOption(id: 1, description: 'VIEW'),
          PrivilegeOption(id: 3, description: 'UPDATE'),
          PrivilegeOption(id: 5, description: 'PRINT'),
        ]),
      );
      grantAllPrivileges();
    });

    tearDown(revokeAllPrivileges);

    Future<void> pumpPage(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpLocalized(
        tester,
        MultiBlocProvider(
          providers: [
            BlocProvider<InterfaceBloc>(
              create: (_) => InterfaceBloc(repository)..add(const RegisterListRequested()),
            ),
            BlocProvider<PrivilegeOptionsCubit>(
              create: (_) => PrivilegeOptionsCubit(repository.listPrivilegeOptions)..load(),
            ),
          ],
          child: const InterfacePage(),
        ),
      );
    }

    Finder field(String name) => find.byKey(Key('register-field-$name'));

    testWidgets('a row opens the form with its privileges checked from the catalog', (tester) async {
      await pumpPage(tester);

      expect(find.text('users · Access'), findsOneWidget);
      await tester.tap(find.byKey(RegisterSearchPage.rowKey(4)));
      await tester.pumpAndSettle();

      expect(find.text('Screen users'), findsOneWidget);
      expect(tester.widget<VgrCheckboxTile>(field('privilegeIds-1')).value, isTrue);
      expect(tester.widget<VgrCheckboxTile>(field('privilegeIds-5')).value, isFalse);
    });

    testWidgets('a key that is not lower_snake_case is caught before the round trip', (tester) async {
      await pumpPage(tester);
      await tester.tap(find.byKey(RegisterSearchPage.newButtonKey));
      await tester.pumpAndSettle();

      await tester.enterText(field('description'), 'Reports');
      await tester.enterText(field('i18nKey'), 'Reports-List');
      await tester.tap(find.byKey(VgrFormShell.saveKey));
      await tester.pumpAndSettle();

      expect(find.text('Stable key (lower_snake_case): Invalid format.'), findsOneWidget);
      verifyNever(() => repository.create(any()));
    });

    testWidgets('a new screen is saved with the checked privileges, sorted', (tester) async {
      when(() => repository.create(any())).thenAnswer((_) async => const Right(users));
      await pumpPage(tester);
      await tester.tap(find.byKey(RegisterSearchPage.newButtonKey));
      await tester.pumpAndSettle();

      await tester.enterText(field('description'), 'Reports');
      await tester.enterText(field('i18nKey'), 'reports');
      await tester.tap(field('privilegeIds-5'));
      await tester.tap(field('privilegeIds-1'));
      await tester.tap(find.byKey(VgrFormShell.saveKey));
      await tester.pumpAndSettle();

      verify(() => repository.create(const InterfaceDraft(
            description: 'Reports',
            i18nKey: 'reports',
            groupDefault: 'General',
            kind: 'T',
            position: 0,
            privilegeIds: [1, 5],
          ))).called(1);
    });

    testWidgets('a privilege catalog that fails to load says so in the form', (tester) async {
      when(() => repository.listPrivilegeOptions()).thenAnswer(
        (_) async => const Left(Failure(message: 'Forbidden', statusCode: 403, code: 'FORBIDDEN')),
      );
      await pumpPage(tester);
      await tester.tap(find.byKey(RegisterSearchPage.newButtonKey));
      await tester.pumpAndSettle();

      expect(find.textContaining('permission'), findsOneWidget);
    });
  });
}
