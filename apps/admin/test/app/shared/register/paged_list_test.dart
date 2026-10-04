import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vgr_admin/app/shared/register/paged_list_bloc.dart';
import 'package:vgr_admin/app/shared/register/paged_list_screen.dart';
import 'package:vgr_admin/app/shared/register/register_event.dart';
import 'package:vgr_admin/app/shared/register/register_lookup.dart';
import 'package:vgr_admin/app/shared/register/register_search_page.dart';
import 'package:vgr_admin/app/shared/register/register_state.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../helpers/pump_localized.dart';

/// A workflow row action, the way a Legal Gate or queue bloc declares one.
final class Approve extends RegisterEvent {
  const Approve(this.id);

  final int id;

  @override
  List<Object?> get props => [id];
}

/// A queue whose rows leave when approved — the server's answer, not a
/// local guess.
class QueueBloc extends PagedListBloc<int> {
  QueueBloc({this.failApprove = false}) {
    on<Approve>((event, emit) => act(
          emit,
          () async {
            if (failApprove) {
              return const Left<Failure, Unit>(Failure(message: 'gone', statusCode: 409, code: 'BUSINESS_RULE'));
            }
            rows.remove(event.id);
            return const Right<Failure, Unit>(unit);
          },
          successKey: 'register.saved',
        ));
  }

  final bool failApprove;
  final rows = [1, 2, 3];
  final queries = <PagedQuery>[];

  @override
  Future<Either<Failure, PagedResult<int>>> fetch(PagedQuery query) async {
    queries.add(query);
    return Right(PagedResult(items: List.of(rows), page: query.page, pageSize: query.pageSize, total: rows.length));
  }
}

/// The list half of the factory on its own (PS3 — decision 220 on the
/// workflow screens): row actions through `act`, outcomes to the bridge.
void main() {
  group('PagedListBloc.act', () {
    test('a success is signalled and the list reloads QUIETLY (no loading state)', () async {
      final bloc = QueueBloc()..add(const RegisterListRequested());
      await bloc.stream.firstWhere((state) => state is RegisterListLoaded<int>);

      bloc.add(const Approve(2));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          const RegisterActionSuccess<int>('register.saved'),
          RegisterListLoaded<int>(const PagedQuery(), const PagedResult(items: [1, 3], page: 1, pageSize: 20, total: 2)),
        ]),
      );
      await bloc.close();
    });

    test('a failure is signalled and the list is reloaded from the server, still quietly', () async {
      final bloc = QueueBloc(failApprove: true)..add(const RegisterListRequested());
      await bloc.stream.firstWhere((state) => state is RegisterListLoaded<int>);

      bloc.add(const Approve(2));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<RegisterActionFailure<int>>(),
          isA<RegisterListLoaded<int>>(),
        ]),
      );
      expect(bloc.queries, hasLength(2));
      await bloc.close();
    });
  });

  group('PagedListScreen', () {
    Future<QueueBloc> pump(WidgetTester tester, {bool failApprove = false, bool filterable = true}) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bloc = QueueBloc(failApprove: failApprove)..add(const RegisterListRequested());
      await pumpLocalized(
        tester,
        BlocProvider<QueueBloc>.value(
          value: bloc,
          child: PagedListScreen<int, QueueBloc>(
            title: 'Queue',
            filterable: filterable,
            header: const VgrText('header', key: Key('queue-header')),
            rowId: (row) => row,
            rowBuilder: (context, row) => RegisterRow(
              title: 'Row $row',
              trailing: VgrIconButton(
                key: Key('approve-$row'),
                icon: VgrIconName.check,
                tooltip: 'Approve',
                onPressed: () => context.read<QueueBloc>().add(Approve(row)),
              ),
            ),
          ),
        ),
      );
      return bloc;
    }

    testWidgets('rows, header and filter; a row action reports success and the row leaves', (tester) async {
      await pump(tester);

      expect(find.byKey(const Key('queue-header')), findsOneWidget);
      expect(find.byKey(VgrSearchBar.fieldKey), findsOneWidget);
      expect(find.byKey(RegisterSearchPage.newButtonKey), findsNothing);

      await tester.tap(find.byKey(const Key('approve-2')));
      await tester.pumpAndSettle();

      expect(find.text('Record saved.'), findsOneWidget);
      expect(find.text('Row 2'), findsNothing);
      expect(find.text('Row 3'), findsOneWidget);
    });

    testWidgets('a refused action goes through the bridge and the list stays', (tester) async {
      await pump(tester, failApprove: true);

      await tester.tap(find.byKey(const Key('approve-2')));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Row 2'), findsOneWidget);
    });

    testWidgets('filterable false hides the search bar', (tester) async {
      await pump(tester, filterable: false);
      expect(find.byKey(VgrSearchBar.fieldKey), findsNothing);
    });
  });

  group('RegisterLookupCubit', () {
    test('loading → loaded with the items', () async {
      final cubit = RegisterLookupCubit<int>(() async => const Right([7, 8]));
      expect(cubit.state, const RegisterLookupLoading<int>());

      await cubit.load();
      expect(cubit.state.items, [7, 8]);
      await cubit.close();
    });

    test('a failure is kept as a state the field can show', () async {
      const failure = Failure(message: 'down', statusCode: 503);
      final cubit = RegisterLookupCubit<int>(() async => const Left(failure));

      await cubit.load();
      expect(cubit.state, const RegisterLookupFailed<int>(failure));
      expect(cubit.state.items, isEmpty);
      await cubit.close();
    });
  });
}
