import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/system-modules/data/system_module_repository_impl.dart';
import 'package:vgr_admin/app/modules/system-modules/domain/entity/system_module_entity.dart';
import 'package:vgr_admin/app/modules/system-modules/domain/repository/system_module_repository.dart';
import 'package:vgr_admin/app/modules/system-modules/presentation/bloc/system_module_bloc.dart';
import 'package:vgr_admin/app/modules/system-modules/presentation/page/system_module_page.dart';
import 'package:vgr_admin/app/shared/register/register_search_page.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../helpers/pump_localized.dart';
import '../../../helpers/session_access.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockSystemModuleRepository extends Mock implements SystemModuleRepository {}

/// Menu modules on the register factory (PS3): the checked screens keep
/// the order they were checked in — that order IS the menu.
void main() {
  const access = SystemModuleEntity(
    id: 7,
    description: 'Access control',
    i18nKey: 'access',
    position: 1,
    interfaceIds: [12, 10],
  );

  group('repository', () {
    test('the list is paged (PS0); the screen options are the unpaged catalog', () async {
      final apiClient = MockApiClient();
      final repository = SystemModuleRepositoryImpl(apiClient);
      when(() => apiClient.get('/api/system-modules?page=1&pageSize=20')).thenAnswer(
        (_) async => {
          'ok': true,
          'data': {
            'items': [
              {'id': 7, 'description': 'Access control', 'interfaceIds': [12, 10]},
            ],
            'page': 1,
            'pageSize': 20,
            'total': 1,
          },
        },
      );
      when(() => apiClient.get('/api/interfaces')).thenAnswer(
        (_) async => {
          'ok': true,
          'data': [
            {'id': 10, 'description': 'Users', 'i18nKey': 'users'},
          ],
        },
      );

      final page = await repository.list(const PagedQuery());
      final options = await repository.listInterfaceOptions();

      page.fold((f) => fail('$f'), (page) => expect(page.items.single.interfaceIds, [12, 10]));
      options.fold((f) => fail('$f'), (list) => expect(list.single.i18nKey, 'users'));
    });
  });

  group('page', () {
    late MockSystemModuleRepository repository;

    setUpAll(() {
      registerFallbackValue(const PagedQuery());
      registerFallbackValue(const SystemModuleDraft(description: '', position: 0, interfaceIds: []));
      registerFallbackValue(access);
    });

    setUp(() {
      repository = MockSystemModuleRepository();
      when(() => repository.list(any())).thenAnswer(
        (_) async => const Right(PagedResult(items: [access], page: 1, pageSize: 20, total: 1)),
      );
      when(() => repository.listInterfaceOptions()).thenAnswer(
        (_) async => const Right([
          InterfaceOption(id: 10, description: 'Users', i18nKey: 'users'),
          InterfaceOption(id: 11, description: 'Privileges', i18nKey: 'privileges'),
          InterfaceOption(id: 12, description: 'Interfaces', i18nKey: 'interfaces'),
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
            BlocProvider<SystemModuleBloc>(
              create: (_) => SystemModuleBloc(repository)..add(const RegisterListRequested()),
            ),
            BlocProvider<InterfaceOptionsCubit>(
              create: (_) => InterfaceOptionsCubit(repository.listInterfaceOptions)..load(),
            ),
          ],
          child: const SystemModulePage(),
        ),
      );
    }

    Finder field(String name) => find.byKey(Key('register-field-$name'));

    testWidgets('the row counts the screens; the form shows each one at its menu position',
        (tester) async {
      await pumpPage(tester);
      expect(find.text('2 screens'), findsOneWidget);

      await tester.tap(find.byKey(RegisterSearchPage.rowKey(7)));
      await tester.pumpAndSettle();

      expect(tester.widget<VgrCheckboxTile>(field('interfaceIds-12')).trailingText, '1');
      expect(tester.widget<VgrCheckboxTile>(field('interfaceIds-10')).trailingText, '2');
      expect(tester.widget<VgrCheckboxTile>(field('interfaceIds-11')).trailingText, isNull);
    });

    testWidgets('saving keeps the check order and sends blank optionals as null', (tester) async {
      when(() => repository.update(any(), any())).thenAnswer((_) async => const Right(access));
      await pumpPage(tester);
      await tester.tap(find.byKey(RegisterSearchPage.rowKey(7)));
      await tester.pumpAndSettle();

      await tester.enterText(field('i18nKey'), '');
      await tester.tap(field('interfaceIds-12')); // uncheck the first…
      await tester.pump();
      await tester.tap(field('interfaceIds-11'));
      await tester.pump();
      await tester.tap(field('interfaceIds-12')); // …and put it back last
      await tester.pump();
      await tester.tap(find.byKey(VgrFormShell.saveKey));
      await tester.pumpAndSettle();

      verify(() => repository.update(
            access,
            const SystemModuleDraft(description: 'Access control', position: 1, interfaceIds: [10, 11, 12]),
          )).called(1);
    });

    testWidgets('an optional key, when typed, still follows lower_snake_case', (tester) async {
      await pumpPage(tester);
      await tester.tap(find.byKey(RegisterSearchPage.newButtonKey));
      await tester.pumpAndSettle();

      await tester.enterText(field('description'), 'Reports');
      await tester.enterText(field('i18nKey'), 'Reports');
      await tester.tap(find.byKey(VgrFormShell.saveKey));
      await tester.pumpAndSettle();

      expect(find.text('Translation key (optional): Invalid format.'), findsOneWidget);
      verifyNever(() => repository.create(any()));
    });
  });
}
