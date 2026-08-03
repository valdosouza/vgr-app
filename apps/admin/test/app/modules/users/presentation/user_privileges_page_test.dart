import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_widgets/vgr_widgets.dart';
import 'package:vgr_admin/app/modules/users/domain/entity/user_entity.dart';
import 'package:vgr_admin/app/modules/users/domain/repository/user_repository.dart';
import 'package:vgr_admin/app/modules/users/presentation/bloc/user_privileges_bloc.dart';
import 'package:vgr_admin/app/modules/users/presentation/page/user_privileges_page.dart';

import '../../../../helpers/pump_localized.dart';

class MockUserRepository extends Mock implements UserRepository {}

void main() {
  late MockUserRepository repository;

  const user = UserEntity(id: 2, name: 'Ana', email: 'ana@vgr.com.br');

  const matrixBefore = [
    UserInterfaceGrants(
      interfaceId: 1,
      interfaceKey: 'risk_config',
      description: 'Risk Tier Configuration',
      groupDefault: 'Operations',
      privileges: [
        UserPrivilegeCell(privilegeId: 1, description: 'VIEW', granted: false),
        UserPrivilegeCell(privilegeId: 3, description: 'UPDATE', granted: false),
      ],
    ),
  ];

  const matrixAfter = [
    UserInterfaceGrants(
      interfaceId: 1,
      interfaceKey: 'risk_config',
      description: 'Risk Tier Configuration',
      groupDefault: 'Operations',
      privileges: [
        // VIEW came back granted even though only UPDATE was checked — the
        // API implies it (setes rule kept by name).
        UserPrivilegeCell(privilegeId: 1, description: 'VIEW', granted: true),
        UserPrivilegeCell(privilegeId: 3, description: 'UPDATE', granted: true),
      ],
    ),
  ];

  setUp(() {
    repository = MockUserRepository();
    // Decision 93: the checkboxes only respond when the actor holds the
    // user_privileges kind-'R' resource.
    SessionAccess.instance.applyPermissions(const {
      'user_privileges': ['VIEW', 'UPDATE'],
    });
  });

  tearDown(SessionAccess.instance.clear);

  Future<void> pumpPage(WidgetTester tester) async {
    await pumpLocalized(
      tester,
      BlocProvider(
        create: (_) => UserPrivilegesBloc(repository)..add(const UserPrivilegesFetchRequested(2)),
        child: const UserPrivilegesPage(user: user),
      ),
    );
  }

  testWidgets('checking UPDATE submits the grant and re-fetch shows the implied VIEW', (tester) async {
    var fetches = 0;
    when(() => repository.privilegeMatrix(2)).thenAnswer(
      (_) async => Right(++fetches == 1 ? matrixBefore : matrixAfter),
    );
    when(() => repository.syncPrivileges(2, 1, [3])).thenAnswer((_) async => const Right(unit));

    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('grants-risk_config')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('grant-risk_config-UPDATE')));
    await tester.pumpAndSettle();

    verify(() => repository.syncPrivileges(2, 1, [3])).called(1);

    final viewCell = tester.widget<VgrCheckboxTile>(
      find.byKey(const Key('grant-risk_config-VIEW')),
    );
    expect(viewCell.value, isTrue);
    expect(find.text('Privileges updated'), findsOneWidget);
  });

  testWidgets('a failed sync keeps the matrix and surfaces the translated SELF_LOCKOUT error', (tester) async {
    when(() => repository.privilegeMatrix(2)).thenAnswer((_) async => const Right(matrixBefore));
    when(() => repository.syncPrivileges(2, 1, any())).thenAnswer(
      (_) async => const Left(Failure(
        message: 'You cannot revoke your own access to the Users screen',
        statusCode: 409,
        code: 'SELF_LOCKOUT',
      )),
    );

    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('grants-risk_config')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('grant-risk_config-UPDATE')));
    await tester.pumpAndSettle();

    expect(
      find.text('You cannot remove your own administration access.'),
      findsOneWidget,
    );
  });
}
