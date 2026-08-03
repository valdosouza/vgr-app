import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/dual-control-access/domain/entity/dual_control_access_request_entity.dart';
import 'package:vgr_admin/app/modules/dual-control-access/domain/repository/dual_control_access_repository.dart';
import 'package:vgr_admin/app/modules/dual-control-access/presentation/bloc/dual_control_access_bloc.dart';
import 'package:vgr_admin/app/modules/dual-control-access/presentation/page/dual_control_request_page.dart';

class MockDualControlAccessRepository extends Mock implements DualControlAccessRepository {}

void main() {
  late MockDualControlAccessRepository repository;

  setUp(() {
    repository = MockDualControlAccessRepository();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => DualControlAccessBloc(repository),
          child: const DualControlRequestPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'requires 2 distinct admins to grant a dual-control access request',
    (tester) async {
      when(() => repository.create(99, 'Court order #123')).thenAnswer((_) async => const Right('1'));
      when(() => repository.addApproval('1', 'admin-a')).thenAnswer(
        (_) async => const Right(
          DualControlAccessRequestEntity(id: '1', legalBasis: 'Court order #123', approverIds: ['admin-a']),
        ),
      );
      when(() => repository.addApproval('1', 'admin-b')).thenAnswer(
        (_) async => const Right(
          DualControlAccessRequestEntity(id: '1', legalBasis: 'Court order #123', approverIds: ['admin-a', 'admin-b']),
        ),
      );

      await pumpPage(tester);

      await tester.enterText(find.byKey(const Key('accountability-log-entry-id-field')), '99');
      await tester.enterText(find.byKey(const Key('legal-basis-field')), 'Court order #123');
      await tester.tap(find.byKey(const Key('start-request-button')));
      await tester.pumpAndSettle();

      expect(find.text('Granted'), findsNothing);

      await tester.enterText(find.byKey(const Key('approver-id-field')), 'admin-a');
      await tester.tap(find.byKey(const Key('add-approval-button')));
      await tester.pumpAndSettle();

      expect(find.text('Granted'), findsNothing);

      await tester.enterText(find.byKey(const Key('approver-id-field')), 'admin-b');
      await tester.tap(find.byKey(const Key('add-approval-button')));
      await tester.pumpAndSettle();

      expect(find.text('Granted'), findsOneWidget);
    },
  );

  testWidgets(
    'shows the Failure message when the same approverId is submitted twice',
    (tester) async {
      when(() => repository.create(99, 'Court order #123')).thenAnswer((_) async => const Right('1'));
      when(() => repository.addApproval('1', 'admin-a')).thenAnswer(
        (_) async => const Left(Failure(message: 'This approver has already approved this request', statusCode: 409)),
      );

      await pumpPage(tester);

      await tester.enterText(find.byKey(const Key('accountability-log-entry-id-field')), '99');
      await tester.enterText(find.byKey(const Key('legal-basis-field')), 'Court order #123');
      await tester.tap(find.byKey(const Key('start-request-button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('approver-id-field')), 'admin-a');
      await tester.tap(find.byKey(const Key('add-approval-button')));
      await tester.pumpAndSettle();

      expect(find.text('This approver has already approved this request'), findsOneWidget);
    },
  );
}
