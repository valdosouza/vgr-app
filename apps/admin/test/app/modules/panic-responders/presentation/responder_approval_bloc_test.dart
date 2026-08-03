import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/panic-responders/domain/entity/responder_approval_entity.dart';
import 'package:vgr_admin/app/modules/panic-responders/domain/repository/responder_approval_repository.dart';
import 'package:vgr_admin/app/modules/panic-responders/presentation/bloc/responder_approval_bloc.dart';
import 'package:vgr_admin/app/modules/panic-responders/presentation/bloc/responder_approval_event.dart';
import 'package:vgr_admin/app/modules/panic-responders/presentation/bloc/responder_approval_state.dart';

class MockResponderApprovalRepository extends Mock implements ResponderApprovalRepository {}

void main() {
  late MockResponderApprovalRepository repository;
  late ResponderApprovalBloc bloc;

  const items = [
    ResponderApprovalEntity(id: 1, userId: 42, status: ResponderApprovalStatus.pending, criteriaNotes: 'notes'),
    ResponderApprovalEntity(id: 2, userId: 43, status: ResponderApprovalStatus.pending, criteriaNotes: null),
  ];

  setUp(() {
    repository = MockResponderApprovalRepository();
    bloc = ResponderApprovalBloc(repository);
  });

  tearDown(() => bloc.close());

  test('emits [Loading, Loaded(list)] on initial fetch', () async {
    when(() => repository.listPending()).thenAnswer((_) async => const Right(items));

    expectLater(
      bloc.stream,
      emitsInOrder([
        isA<ResponderApprovalLoading>(),
        const ResponderApprovalLoaded(items),
      ]),
    );

    bloc.add(const FetchRequested());
  });

  test('approve removes the request from the pending queue without a full page reload', () async {
    when(() => repository.listPending()).thenAnswer((_) async => const Right(items));
    when(() => repository.resolve(1, true)).thenAnswer((_) async => const Right(unit));

    bloc.add(const FetchRequested());
    await bloc.stream.firstWhere((s) => s is ResponderApprovalLoaded);

    expectLater(
      bloc.stream,
      emits(const ResponderApprovalLoaded([
        ResponderApprovalEntity(id: 2, userId: 43, status: ResponderApprovalStatus.pending, criteriaNotes: null),
      ])),
    );

    bloc.add(const ResolveRequested(id: 1, approved: true));

    await Future<void>.delayed(Duration.zero);
    verify(() => repository.listPending()).called(1);
  });

  test('deny removes the request from the pending queue', () async {
    when(() => repository.listPending()).thenAnswer((_) async => const Right(items));
    when(() => repository.resolve(1, false)).thenAnswer((_) async => const Right(unit));

    bloc.add(const FetchRequested());
    await bloc.stream.firstWhere((s) => s is ResponderApprovalLoaded);

    expectLater(
      bloc.stream,
      emits(const ResponderApprovalLoaded([
        ResponderApprovalEntity(id: 2, userId: 43, status: ResponderApprovalStatus.pending, criteriaNotes: null),
      ])),
    );

    bloc.add(const ResolveRequested(id: 1, approved: false));
  });
}
