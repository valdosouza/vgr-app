import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/dual-control-access/domain/entity/dual_control_request_entity.dart';
import 'package:vgr_admin/app/modules/dual-control-access/domain/repository/dual_control_access_repository.dart';
import 'package:vgr_admin/app/modules/dual-control-access/presentation/bloc/dual_control_bloc.dart';

class MockDualControlAccessRepository extends Mock implements DualControlAccessRepository {}

PagedResult<T> _page<T>(List<T> items) => PagedResult(items: items, page: 1, pageSize: 20, total: items.length);

const _pending = DualControlRequestEntity(
  id: 5,
  accountabilityLogEntryId: 1,
  legalBasis: 'Court order #7',
  status: 'pending',
  requestedBy: 7,
  requestedByName: 'Ana',
  createdAt: '2026-10-04T21:38:41.000Z',
);

const _granted = DualControlRequestEntity(
  id: 5,
  accountabilityLogEntryId: 1,
  legalBasis: 'Court order #7',
  status: 'granted',
  requestedBy: 7,
  requestedByName: 'Ana',
  approvedBy: 8,
  approvedByName: 'Bia',
  approvedAt: '2026-10-04T21:40:00.000Z',
  createdAt: '2026-10-04T21:38:41.000Z',
);

const _draft = DualControlRequestDraft(accountabilityLogEntryId: 1, legalBasis: 'Court order #7');

const _selfApproval = Failure(
  message: 'The approver must be a different user than the requester',
  statusCode: 422,
  code: 'BUSINESS_RULE',
);

/// The decision 45 gate on the factory (decision 227).
void main() {
  late MockDualControlAccessRepository repository;

  setUpAll(() => registerFallbackValue(const PagedQuery()));

  setUp(() => repository = MockDualControlAccessRepository());

  test('opening a request is the factory save: signalled, then the page reloads', () async {
    when(() => repository.list(any())).thenAnswer((_) async => Right(_page(const <DualControlRequestEntity>[])));
    when(() => repository.request(_draft)).thenAnswer((_) async => const Right(_pending));
    final bloc = DualControlBloc(repository)..add(const RegisterListRequested());
    await bloc.stream.firstWhere((s) => s is RegisterListLoaded<DualControlRequestEntity>);

    bloc.add(const RegisterNewPressed());
    bloc.add(const RegisterSaveRequested(_draft));

    await expectLater(
      bloc.stream,
      emitsThrough(const RegisterActionSuccess<DualControlRequestEntity>('register.saved')),
    );
    verify(() => repository.request(_draft)).called(1);
    await bloc.close();
  });

  test('an approval is signalled and the page reloads with the server\'s answer (224)', () async {
    var calls = 0;
    when(() => repository.list(any())).thenAnswer((_) async => Right(_page([calls++ == 0 ? _pending : _granted])));
    when(() => repository.approve(5)).thenAnswer((_) async => const Right(_granted));
    final bloc = DualControlBloc(repository)..add(const RegisterListRequested());
    await bloc.stream.firstWhere((s) => s is RegisterListLoaded<DualControlRequestEntity>);

    bloc.add(const DualControlApproved(5));

    await expectLater(
      bloc.stream,
      emitsInOrder([
        const RegisterActionSuccess<DualControlRequestEntity>(DualControlBloc.approvedKey),
        RegisterListLoaded<DualControlRequestEntity>(const PagedQuery(), _page([_granted])),
      ]),
    );
    await bloc.close();
  });

  test('a refused approval is signalled and the list stays', () async {
    when(() => repository.list(any())).thenAnswer((_) async => Right(_page([_pending])));
    when(() => repository.approve(5)).thenAnswer((_) async => const Left(_selfApproval));
    final bloc = DualControlBloc(repository)..add(const RegisterListRequested());
    await bloc.stream.firstWhere((s) => s is RegisterListLoaded<DualControlRequestEntity>);

    bloc.add(const DualControlApproved(5));

    await expectLater(
      bloc.stream,
      emitsInOrder([
        const RegisterActionFailure<DualControlRequestEntity>(_selfApproval),
        RegisterListLoaded<DualControlRequestEntity>(const PagedQuery(), _page([_pending])),
      ]),
    );
    await bloc.close();
  });
}
