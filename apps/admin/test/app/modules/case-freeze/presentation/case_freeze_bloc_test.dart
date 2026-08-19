import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/case-freeze/domain/entity/case_freeze_state_entity.dart';
import 'package:vgr_admin/app/modules/case-freeze/domain/repository/case_freeze_repository.dart';
import 'package:vgr_admin/app/modules/case-freeze/presentation/bloc/case_freeze_bloc.dart';
import 'package:vgr_admin/app/modules/case-freeze/presentation/bloc/case_freeze_event.dart';
import 'package:vgr_admin/app/modules/case-freeze/presentation/bloc/case_freeze_state.dart';

class MockCaseFreezeRepository extends Mock implements CaseFreezeRepository {}

const _open = CaseFreezeStateEntity(reportId: 5, status: 'open', frozen: false);
const _frozen = CaseFreezeStateEntity(
  reportId: 5,
  status: 'open',
  frozen: true,
  frozenReason: 'Writ 123/2026',
);

void main() {
  late MockCaseFreezeRepository repository;

  setUp(() => repository = MockCaseFreezeRepository());

  CaseFreezeBloc build() => CaseFreezeBloc(repository);

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('lookup loads the server state', () async {
    when(() => repository.getState(5)).thenAnswer((_) async => const Right(_open));

    final bloc = build()..add(const CaseLookupRequested(5));
    await settle();

    expect(bloc.state, const CaseFreezeLoaded(_open));
  });

  test('a failed lookup is a LookupError, retryable', () async {
    when(() => repository.getState(5)).thenAnswer((_) async =>
        const Left(Failure(message: 'gone', statusCode: 404, code: 'NOT_FOUND')));

    final bloc = build()..add(const CaseLookupRequested(5));
    await settle();

    expect((bloc.state as CaseFreezeLookupError).failure.code, 'NOT_FOUND');
  });

  test('freeze re-fetches: the screen renders what the SERVER says', () async {
    when(() => repository.getState(5)).thenAnswer((_) async => const Right(_open));
    final bloc = build()..add(const CaseLookupRequested(5));
    await settle();

    when(() => repository.freeze(5, 'Writ 123/2026'))
        .thenAnswer((_) async => const Right(null));
    when(() => repository.getState(5)).thenAnswer((_) async => const Right(_frozen));

    bloc.add(const CaseFreezeSubmitted('Writ 123/2026'));
    await settle();

    expect(bloc.state, const CaseFreezeLoaded(_frozen));
    verify(() => repository.freeze(5, 'Writ 123/2026')).called(1);
  });

  test('a rejected action keeps the case on screen with the failure '
      '(e.g. same-user approval, 141d)', () async {
    when(() => repository.getState(5)).thenAnswer((_) async => const Right(_frozen));
    final bloc = build()..add(const CaseLookupRequested(5));
    await settle();

    const failure = Failure(
        message: 'The approver must be a different user than the requester',
        statusCode: 422,
        code: 'BUSINESS_RULE');
    when(() => repository.approveUnfreeze(5))
        .thenAnswer((_) async => const Left(failure));

    bloc.add(const UnfreezeApproveSubmitted());
    await settle();

    expect(bloc.state, const CaseFreezeLoaded(_frozen, failure: failure));
  });

  test('mutations without a loaded case are a no-op', () async {
    final bloc = build()..add(const CaseFreezeSubmitted('Writ 123/2026'));
    await settle();

    expect(bloc.state, const CaseFreezeInitial());
    verifyNever(() => repository.freeze(any(), any()));
  });
}
