import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/panic-responders/domain/entity/responder_approval_entity.dart';
import 'package:vgr_admin/app/modules/panic-responders/domain/repository/responder_approval_repository.dart';
import 'package:vgr_admin/app/modules/panic-responders/presentation/bloc/responder_approval_bloc.dart';
import 'package:vgr_admin/app/modules/panic-responders/presentation/bloc/responder_approval_event.dart';
import 'package:vgr_admin/app/modules/panic-responders/presentation/page/responder_approval_queue_page.dart';
import '../../../../helpers/session_access.dart';

import '../../../../helpers/pump_localized.dart';

class MockResponderApprovalRepository extends Mock implements ResponderApprovalRepository {}


void main() {
  late MockResponderApprovalRepository repository;

  setUp(() {
    grantAllPrivileges();
    repository = MockResponderApprovalRepository();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await pumpLocalized(
      tester,
      BlocProvider(
        create: (_) => ResponderApprovalBloc(repository)..add(const FetchRequested()),
        child: const ResponderApprovalQueuePage(),
      ),
    );
  }

  testWidgets('lists 1 pending request with its free-text criteria notes', (tester) async {
    when(() => repository.listPending()).thenAnswer(
      (_) async => const Right([
        ResponderApprovalEntity(
          id: 1,
          userId: 42,
          status: ResponderApprovalStatus.pending,
          criteriaNotes: 'Volunteer firefighter, 5 years',
        ),
      ]),
    );

    await pumpPage(tester);

    expect(find.textContaining('42'), findsOneWidget);
    expect(find.text('Volunteer firefighter, 5 years'), findsOneWidget);
  });

  testWidgets('tapping Approve removes the request from the pending queue', (tester) async {
    when(() => repository.listPending()).thenAnswer(
      (_) async => const Right([
        ResponderApprovalEntity(id: 1, userId: 42, status: ResponderApprovalStatus.pending, criteriaNotes: null),
      ]),
    );
    when(() => repository.resolve(1, true)).thenAnswer((_) async => const Right(unit));

    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('approve-1')));
    await tester.pumpAndSettle();

    verify(() => repository.resolve(1, true)).called(1);
    expect(find.byKey(const Key('responder-request-1')), findsNothing);
  });

  testWidgets('tapping Deny removes the request from the pending queue', (tester) async {
    when(() => repository.listPending()).thenAnswer(
      (_) async => const Right([
        ResponderApprovalEntity(id: 1, userId: 42, status: ResponderApprovalStatus.pending, criteriaNotes: null),
      ]),
    );
    when(() => repository.resolve(1, false)).thenAnswer((_) async => const Right(unit));

    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('deny-1')));
    await tester.pumpAndSettle();

    verify(() => repository.resolve(1, false)).called(1);
    expect(find.byKey(const Key('responder-request-1')), findsNothing);
  });
}
