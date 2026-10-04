import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/panic-responders/domain/entity/responder_approval_entity.dart';
import 'package:vgr_admin/app/modules/panic-responders/domain/repository/responder_approval_repository.dart';
import 'package:vgr_admin/app/modules/panic-responders/presentation/bloc/responder_approval_bloc.dart';
import 'package:vgr_admin/app/modules/panic-responders/presentation/page/responder_approval_queue_page.dart';
import 'package:vgr_admin/app/shared/register/register_search_page.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../../helpers/pump_localized.dart';
import '../../../../helpers/session_access.dart';

class MockResponderApprovalRepository extends Mock implements ResponderApprovalRepository {}

const _firefighter = ResponderApprovalEntity(
  id: 1,
  userId: 42,
  status: ResponderApprovalStatus.pending,
  criteriaNotes: 'Volunteer firefighter, 5 years',
);

const _other = ResponderApprovalEntity(
  id: 2,
  userId: 43,
  status: ResponderApprovalStatus.pending,
  criteriaNotes: null,
);

PagedResult<ResponderApprovalEntity> _page(List<ResponderApprovalEntity> items) =>
    PagedResult(items: items, page: 1, pageSize: 20, total: items.length);

/// The authorized-responder queue as a paged list (PS3 — decisions 51-52,
/// 190, 220, 221).
void main() {
  late MockResponderApprovalRepository repository;

  setUpAll(() => registerFallbackValue(const PagedQuery()));

  setUp(() {
    repository = MockResponderApprovalRepository();
    grantAllPrivileges();
  });

  tearDown(revokeAllPrivileges);

  Future<void> pumpQueue(WidgetTester tester) async {
    await pumpLocalized(
      tester,
      BlocProvider<ResponderApprovalBloc>(
        create: (_) => ResponderApprovalBloc(repository)..add(const RegisterListRequested()),
        child: const ResponderApprovalQueuePage(),
      ),
    );
  }

  group('bloc', () {
    test('a resolved request leaves because the reloaded page says so', () async {
      var calls = 0;
      when(() => repository.listPending(any()))
          .thenAnswer((_) async => _page(++calls == 1 ? const [_firefighter, _other] : const [_other]).let(Right.new));
      when(() => repository.resolve(1, true)).thenAnswer((_) async => const Right(unit));
      final bloc = ResponderApprovalBloc(repository)..add(const RegisterListRequested());
      await bloc.stream.firstWhere((s) => s is RegisterListLoaded<ResponderApprovalEntity>);

      bloc.add(const ResolveRequested(id: 1, approved: true));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          const RegisterActionSuccess<ResponderApprovalEntity>('panicResponders.approved'),
          RegisterListLoaded<ResponderApprovalEntity>(const PagedQuery(), _page(const [_other])),
        ]),
      );
      await bloc.close();
    });
  });

  group('page', () {
    testWidgets('lists the pending requests with their free-text criteria notes, no filter', (tester) async {
      when(() => repository.listPending(any())).thenAnswer((_) async => Right(_page(const [_firefighter])));
      await pumpQueue(tester);

      expect(find.text('User #42'), findsOneWidget);
      expect(find.text('Volunteer firefighter, 5 years'), findsOneWidget);
      expect(find.byKey(VgrSearchBar.fieldKey), findsNothing);
    });

    testWidgets('approve and deny each resolve their request; the queue confirms it', (tester) async {
      var remaining = [_firefighter, _other];
      when(() => repository.listPending(any())).thenAnswer((_) async => Right(_page(List.of(remaining))));
      when(() => repository.resolve(any(), any())).thenAnswer((invocation) async {
        final id = invocation.positionalArguments.first as int;
        remaining = remaining.where((item) => item.id != id).toList();
        return const Right(unit);
      });
      await pumpQueue(tester);

      await tester.tap(find.byKey(const Key('approve-1')));
      await tester.pumpAndSettle();
      expect(find.text('Request approved.'), findsOneWidget);
      expect(find.byKey(RegisterSearchPage.rowKey(1)), findsNothing);

      await tester.tap(find.byKey(const Key('deny-2')));
      await tester.pumpAndSettle();
      verify(() => repository.resolve(2, false)).called(1);
      expect(find.text('No pending requests'), findsOneWidget);
    });

    testWidgets('a refused resolve keeps the queue on screen (it used to replace it with an error)',
        (tester) async {
      when(() => repository.listPending(any())).thenAnswer((_) async => Right(_page(const [_firefighter])));
      when(() => repository.resolve(1, true)).thenAnswer(
        (_) async => const Left(Failure(message: 'Forbidden', statusCode: 403, code: 'FORBIDDEN')),
      );
      await pumpQueue(tester);

      await tester.tap(find.byKey(const Key('approve-1')));
      await tester.pumpAndSettle();

      expect(find.text('You do not have permission for this action.'), findsOneWidget);
      expect(find.text('User #42'), findsOneWidget);
    });

    testWidgets('without the UPDATE grant approve/deny render disabled (can() wired — decision 71)',
        (tester) async {
      when(() => repository.listPending(any())).thenAnswer((_) async => Right(_page(const [_firefighter])));
      revokeAllPrivileges();
      await pumpQueue(tester);

      // Asserts on the house widget, not on Flutter's IconButton (133).
      expect(tester.widget<VgrIconButton>(find.byKey(const Key('approve-1'))).onPressed, isNull);
      expect(tester.widget<VgrIconButton>(find.byKey(const Key('deny-1'))).onPressed, isNull);
    });
  });
}

extension<T> on T {
  R let<R>(R Function(T value) apply) => apply(this);
}
