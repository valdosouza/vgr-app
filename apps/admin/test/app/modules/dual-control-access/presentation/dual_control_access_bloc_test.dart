import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/dual-control-access/domain/entity/dual_control_access_request_entity.dart';
import 'package:vgr_admin/app/modules/dual-control-access/domain/repository/dual_control_access_repository.dart';
import 'package:vgr_admin/app/modules/dual-control-access/presentation/bloc/dual_control_access_bloc.dart';
import 'package:vgr_admin/app/modules/dual-control-access/presentation/bloc/dual_control_access_event.dart';
import 'package:vgr_admin/app/modules/dual-control-access/presentation/bloc/dual_control_access_state.dart';

class MockDualControlAccessRepository extends Mock implements DualControlAccessRepository {}

void main() {
  late MockDualControlAccessRepository repository;
  late DualControlAccessBloc bloc;

  setUp(() {
    repository = MockDualControlAccessRepository();
    bloc = DualControlAccessBloc(repository);
  });

  tearDown(() => bloc.close());

  test('emits Progress with an empty approverIds set after creating a request', () async {
    when(() => repository.create(99, 'Court order #123')).thenAnswer((_) async => const Right('1'));

    expectLater(
      bloc.stream,
      emits(const DualControlProgress(
        DualControlAccessRequestEntity(id: '1', legalBasis: 'Court order #123', approverIds: []),
      )),
    );

    bloc.add(const RequestSubmitted(accountabilityLogEntryId: 99, legalBasis: 'Court order #123'));
  });

  test('emits Progress (not ActionSuccess) after the first distinct approval', () async {
    when(() => repository.create(99, 'Court order #123')).thenAnswer((_) async => const Right('1'));
    when(() => repository.addApproval('1', 'admin-a')).thenAnswer(
      (_) async => const Right(
        DualControlAccessRequestEntity(id: '1', legalBasis: 'Court order #123', approverIds: ['admin-a']),
      ),
    );

    bloc.add(const RequestSubmitted(accountabilityLogEntryId: 99, legalBasis: 'Court order #123'));
    await bloc.stream.firstWhere((s) => s is DualControlProgress);

    expectLater(
      bloc.stream,
      emits(const DualControlProgress(
        DualControlAccessRequestEntity(id: '1', legalBasis: 'Court order #123', approverIds: ['admin-a']),
      )),
    );

    bloc.add(const ApprovalSubmitted(approverId: 'admin-a'));
  });

  test('emits a one-shot ActionSuccess only when the second distinct approval is recorded, not the first', () async {
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

    bloc.add(const RequestSubmitted(accountabilityLogEntryId: 99, legalBasis: 'Court order #123'));
    await bloc.stream.firstWhere((s) => s is DualControlProgress);

    bloc.add(const ApprovalSubmitted(approverId: 'admin-a'));
    await bloc.stream.firstWhere(
      (s) => s is DualControlProgress && s.entity.approverIds.length == 1,
    );

    expectLater(
      bloc.stream,
      emits(const DualControlActionSuccess(
        DualControlAccessRequestEntity(id: '1', legalBasis: 'Court order #123', approverIds: ['admin-a', 'admin-b']),
      )),
    );

    bloc.add(const ApprovalSubmitted(approverId: 'admin-b'));
  });

  test('emits Error when the repository reports a duplicated approverId (409)', () async {
    when(() => repository.create(99, 'Court order #123')).thenAnswer((_) async => const Right('1'));
    when(() => repository.addApproval('1', 'admin-a')).thenAnswer(
      (_) async => const Left(Failure(message: 'This approver has already approved this request', statusCode: 409)),
    );

    bloc.add(const RequestSubmitted(accountabilityLogEntryId: 99, legalBasis: 'Court order #123'));
    await bloc.stream.firstWhere((s) => s is DualControlProgress);

    expectLater(
      bloc.stream,
      emits(const DualControlError('This approver has already approved this request')),
    );

    bloc.add(const ApprovalSubmitted(approverId: 'admin-a'));
  });
}
