import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMenuRepository extends Mock implements MenuRepository {}

const _tree = [
  MenuModule(id: null, description: 'Operations', interfaces: [
    MenuInterface(id: 1, description: 'Risk', i18nKey: 'risk_config'),
    MenuInterface(id: 2, description: 'Reports', i18nKey: 'reports'),
  ]),
  MenuModule(id: 9, description: 'Administration', i18nKey: 'admin', interfaces: [
    MenuInterface(id: 6, description: 'Users', i18nKey: 'users'),
  ]),
];

void main() {
  late MockMenuRepository repository;

  setUp(() {
    repository = MockMenuRepository();
    SessionAccess.instance.clear();
    when(() => repository.getMenus()).thenAnswer((_) async => const Right(_tree));
    when(() => repository.getPermissions())
        .thenAnswer((_) async => const Left(Failure(message: 'offline')));
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('loads with no selection', () async {
    final bloc = MenuBloc(repository)..add(const MenuRequested());
    await settle();

    final loaded = bloc.state as MenuLoaded;
    expect(loaded.selectedModuleIndex, isNull);
    expect(loaded.selectedModule, isNull);
    expect(loaded.selectedInterfaceKey, isNull);
  });

  test('selecting a module exposes its screens; the screen selection is untouched', () async {
    final bloc = MenuBloc(repository)..add(const MenuRequested());
    await settle();
    bloc.add(const MenuModuleSelected(1));
    await settle();

    final loaded = bloc.state as MenuLoaded;
    expect(loaded.selectedModule?.description, 'Administration');
    expect(loaded.selectedInterfaceKey, isNull);
  });

  test('an out-of-range module index is ignored', () async {
    final bloc = MenuBloc(repository)..add(const MenuRequested());
    await settle();
    bloc.add(const MenuModuleSelected(7));
    await settle();

    expect((bloc.state as MenuLoaded).selectedModuleIndex, isNull);
  });

  test('selecting a screen also selects the module that holds it (URL sync after refresh)',
      () async {
    final bloc = MenuBloc(repository)..add(const MenuRequested());
    await settle();
    bloc.add(const MenuInterfaceSelected('users'));
    await settle();

    final loaded = bloc.state as MenuLoaded;
    expect(loaded.selectedModuleIndex, 1);
    expect(loaded.selectedInterfaceKey, 'users');
  });

  test('an unknown screen key leaves the selection alone', () async {
    final bloc = MenuBloc(repository)..add(const MenuRequested());
    await settle();
    bloc
      ..add(const MenuInterfaceSelected('reports'))
      ..add(const MenuInterfaceSelected('nowhere'));
    await settle();

    final loaded = bloc.state as MenuLoaded;
    expect(loaded.selectedModuleIndex, 0);
    expect(loaded.selectedInterfaceKey, 'reports');
  });

  test('selection events before the tree is loaded are no-ops', () async {
    when(() => repository.getMenus())
        .thenAnswer((_) async => const Left(Failure(message: 'Internal error', statusCode: 500)));
    final bloc = MenuBloc(repository)..add(const MenuRequested());
    await settle();
    bloc.add(const MenuInterfaceSelected('users'));
    await settle();

    expect(bloc.state, isA<MenuError>());
  });
}
