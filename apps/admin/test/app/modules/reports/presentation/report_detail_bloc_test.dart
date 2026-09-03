import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/reports/domain/entity/chat_evidence_entities.dart';
import 'package:vgr_admin/app/modules/reports/domain/entity/report_entities.dart';
import 'package:vgr_admin/app/modules/reports/domain/repository/reports_repository.dart';
import 'package:vgr_admin/app/modules/reports/presentation/bloc/report_detail_bloc.dart';
import 'package:vgr_admin/app/modules/reports/presentation/bloc/report_detail_event.dart';
import 'package:vgr_admin/app/modules/reports/presentation/bloc/report_detail_state.dart';

class MockReportsRepository extends Mock implements ReportsRepository {}

ReportPanelDetailEntity detail({bool frozen = false, bool hidden = false, bool reviewed = false}) =>
    ReportPanelDetailEntity(
      reviewedAt: reviewed ? '2026-09-02T09:00:00.000Z' : null,
      reviewedBy: reviewed ? 4 : null,
      reportId: 7,
      category: 'assault',
      freeTag: null,
      subject: 'child',
      tier: 'high',
      status: 'open',
      anonymous: true,
      frozen: frozen,
      frozenReason: frozen ? 'Writ 1/2026' : null,
      frozenAt: frozen ? '2026-09-01T11:00:00.000Z' : null,
      purged: false,
      createdAt: '2026-09-01T10:00:00.000Z',
      resolvedAt: null,
      expiresAt: null,
      hidden: hidden,
      hiddenReasonCode: hidden ? 'spam' : null,
      hiddenNote: null,
      hiddenAt: hidden ? '2026-09-02T09:00:00.000Z' : null,
      hiddenBy: hidden ? 4 : null,
      reporter: null,
      position: const ReportPositionEntity(lat: -23.55, lng: -46.63, precisionMeters: 1100),
      detailFields: null,
      timeline: const [],
      media: const [],
      offers: const [],
    );

const _open = ReportFreezeStateEntity(reportId: 7, status: 'open', frozen: false);
const _frozen = ReportFreezeStateEntity(
  reportId: 7,
  status: 'open',
  frozen: true,
  frozenReason: 'Writ 1/2026',
);
const _exact = ReportExactPositionEntity(reportId: 7, lat: -23.5505, lng: -46.6333);

void main() {
  late MockReportsRepository repository;

  setUp(() => repository = MockReportsRepository());

  ReportDetailBloc build() => ReportDetailBloc(repository);

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('load fetches the detail AND the freeze state', () async {
    when(() => repository.getDetail(7)).thenAnswer((_) async => Right(detail()));
    when(() => repository.getFreezeState(7)).thenAnswer((_) async => const Right(_open));

    final bloc = build()..add(const ReportDetailRequested(7));
    await settle();

    expect(bloc.state, ReportDetailLoaded(detail(), freeze: _open));
  });

  test('a failed detail (404 / no grant) is an error state', () async {
    const failure = Failure(message: 'gone', statusCode: 404, code: 'NOT_FOUND');
    when(() => repository.getDetail(7)).thenAnswer((_) async => const Left(failure));
    when(() => repository.getFreezeState(7)).thenAnswer((_) async => const Right(_open));

    final bloc = build()..add(const ReportDetailRequested(7));
    await settle();

    expect(bloc.state, const ReportDetailError(failure));
  });

  test('a failed freeze state (no case_freeze grant) keeps the detail with freeze = null',
      () async {
    when(() => repository.getDetail(7)).thenAnswer((_) async => Right(detail()));
    when(() => repository.getFreezeState(7)).thenAnswer((_) async =>
        const Left(Failure(message: 'no', statusCode: 403, code: 'FORBIDDEN')));

    final bloc = build()..add(const ReportDetailRequested(7));
    await settle();

    expect(bloc.state, ReportDetailLoaded(detail(), freeze: null));
  });

  test('freeze re-fetches BOTH detail and freeze state (server is the authority)', () async {
    when(() => repository.getDetail(7)).thenAnswer((_) async => Right(detail()));
    when(() => repository.getFreezeState(7)).thenAnswer((_) async => const Right(_open));
    final bloc = build()..add(const ReportDetailRequested(7));
    await settle();

    when(() => repository.freeze(7, 'Writ 1/2026')).thenAnswer((_) async => const Right(null));
    when(() => repository.getDetail(7)).thenAnswer((_) async => Right(detail(frozen: true)));
    when(() => repository.getFreezeState(7)).thenAnswer((_) async => const Right(_frozen));

    bloc.add(const ReportFreezeSubmitted('Writ 1/2026'));
    await settle();

    expect(bloc.state, ReportDetailLoaded(detail(frozen: true), freeze: _frozen));
    verify(() => repository.freeze(7, 'Writ 1/2026')).called(1);
    verify(() => repository.getDetail(7)).called(2);
  });

  test('a rejected action keeps the case on screen with the failure (141d same-user)',
      () async {
    when(() => repository.getDetail(7)).thenAnswer((_) async => Right(detail(frozen: true)));
    when(() => repository.getFreezeState(7)).thenAnswer((_) async => const Right(_frozen));
    final bloc = build()..add(const ReportDetailRequested(7));
    await settle();

    const failure = Failure(message: 'same user', statusCode: 422, code: 'BUSINESS_RULE');
    when(() => repository.approveUnfreeze(7)).thenAnswer((_) async => const Left(failure));

    bloc.add(const ReportUnfreezeApproveSubmitted());
    await settle();

    expect(bloc.state, ReportDetailLoaded(detail(frozen: true), freeze: _frozen, failure: failure));
    verify(() => repository.getDetail(7)).called(1);
  });

  test('request unfreeze posts the reason', () async {
    when(() => repository.getDetail(7)).thenAnswer((_) async => Right(detail(frozen: true)));
    when(() => repository.getFreezeState(7)).thenAnswer((_) async => const Right(_frozen));
    when(() => repository.requestUnfreeze(7, 'Closed')).thenAnswer((_) async => const Right(null));
    final bloc = build()..add(const ReportDetailRequested(7));
    await settle();

    bloc.add(const ReportUnfreezeRequestSubmitted('Closed'));
    await settle();

    verify(() => repository.requestUnfreeze(7, 'Closed')).called(1);
  });

  test('revealing the exact position stores it on the loaded state (decision 159)', () async {
    when(() => repository.getDetail(7)).thenAnswer((_) async => Right(detail()));
    when(() => repository.getFreezeState(7)).thenAnswer((_) async => const Right(_open));
    when(() => repository.getExactPosition(7)).thenAnswer((_) async => const Right(_exact));
    final bloc = build()..add(const ReportDetailRequested(7));
    await settle();

    bloc.add(const ReportExactPositionRequested());
    await settle();

    expect(bloc.state, ReportDetailLoaded(detail(), freeze: _open, exactPosition: _exact));
  });

  test('a refused exact position (no grant, 403) surfaces as the failure, detail kept',
      () async {
    const failure = Failure(message: 'no', statusCode: 403, code: 'FORBIDDEN');
    when(() => repository.getDetail(7)).thenAnswer((_) async => Right(detail()));
    when(() => repository.getFreezeState(7)).thenAnswer((_) async => const Right(_open));
    when(() => repository.getExactPosition(7)).thenAnswer((_) async => const Left(failure));
    final bloc = build()..add(const ReportDetailRequested(7));
    await settle();

    bloc.add(const ReportExactPositionRequested());
    await settle();

    expect(bloc.state, ReportDetailLoaded(detail(), freeze: _open, failure: failure));
  });

  test('actions before a loaded detail are a no-op', () async {
    final bloc = build()
      ..add(const ReportFreezeSubmitted('x'))
      ..add(const ReportExactPositionRequested());
    await settle();

    expect(bloc.state, const ReportDetailInitial());
    verifyNever(() => repository.freeze(any(), any()));
    verifyNever(() => repository.getExactPosition(any()));
  });

  group('moderation — B2 (decisions 162/167): every act re-fetches the detail', () {
    test('hide posts the reason and re-reads the case (hidden arrives from the server)',
        () async {
      when(() => repository.getDetail(7)).thenAnswer((_) async => Right(detail()));
      when(() => repository.getFreezeState(7)).thenAnswer((_) async => const Right(_open));
      final bloc = build()..add(const ReportDetailRequested(7));
      await settle();

      when(() => repository.hide(7, 'spam', null)).thenAnswer((_) async => const Right(null));
      when(() => repository.getDetail(7)).thenAnswer((_) async => Right(detail(hidden: true)));

      bloc.add(const ReportHideSubmitted('spam', null));
      await settle();

      expect(bloc.state, ReportDetailLoaded(detail(hidden: true), freeze: _open));
      verify(() => repository.hide(7, 'spam', null)).called(1);
      verify(() => repository.getDetail(7)).called(2);
    });

    test('unhide with `other` carries the note; a 409 keeps the case with the failure',
        () async {
      when(() => repository.getDetail(7)).thenAnswer((_) async => Right(detail(hidden: true)));
      when(() => repository.getFreezeState(7)).thenAnswer((_) async => const Right(_open));
      final bloc = build()..add(const ReportDetailRequested(7));
      await settle();

      const failure = Failure(message: 'not hidden', statusCode: 409, code: 'DUPLICATE');
      when(() => repository.unhide(7, 'other', 'Cleared'))
          .thenAnswer((_) async => const Left(failure));

      bloc.add(const ReportUnhideSubmitted('other', 'Cleared'));
      await settle();

      expect(bloc.state, ReportDetailLoaded(detail(hidden: true), freeze: _open, failure: failure));
      verify(() => repository.getDetail(7)).called(1);
    });

    test('block / unblock a media re-read the case too', () async {
      when(() => repository.getDetail(7)).thenAnswer((_) async => Right(detail()));
      when(() => repository.getFreezeState(7)).thenAnswer((_) async => const Right(_open));
      when(() => repository.blockMedia('abc', 'illegal_content', null))
          .thenAnswer((_) async => const Right(null));
      when(() => repository.unblockMedia('abc', 'duplicate', null))
          .thenAnswer((_) async => const Right(null));
      final bloc = build()..add(const ReportDetailRequested(7));
      await settle();

      bloc.add(const ReportMediaBlockSubmitted('abc', 'illegal_content', null));
      await settle();
      bloc.add(const ReportMediaUnblockSubmitted('abc', 'duplicate', null));
      await settle();

      verify(() => repository.blockMedia('abc', 'illegal_content', null)).called(1);
      verify(() => repository.unblockMedia('abc', 'duplicate', null)).called(1);
      verify(() => repository.getDetail(7)).called(3);
    });
  });

  group('review — B3 (decision 161)', () {
    test('mark reviewed posts and re-reads the case (reviewedAt arrives from the server)',
        () async {
      when(() => repository.getDetail(7)).thenAnswer((_) async => Right(detail()));
      when(() => repository.getFreezeState(7)).thenAnswer((_) async => const Right(_open));
      final bloc = build()..add(const ReportDetailRequested(7));
      await settle();

      when(() => repository.markReviewed(7)).thenAnswer((_) async => const Right(null));
      when(() => repository.getDetail(7)).thenAnswer((_) async => Right(detail(reviewed: true)));

      bloc.add(const ReportMarkReviewedSubmitted());
      await settle();

      expect(bloc.state, ReportDetailLoaded(detail(reviewed: true), freeze: _open));
      verify(() => repository.markReviewed(7)).called(1);
      verify(() => repository.getDetail(7)).called(2);
    });

    test('a 409 (already reviewed) keeps the case with the failure', () async {
      when(() => repository.getDetail(7)).thenAnswer((_) async => Right(detail()));
      when(() => repository.getFreezeState(7)).thenAnswer((_) async => const Right(_open));
      final bloc = build()..add(const ReportDetailRequested(7));
      await settle();

      const failure = Failure(message: 'already', statusCode: 409, code: 'DUPLICATE');
      when(() => repository.markReviewed(7)).thenAnswer((_) async => const Left(failure));

      bloc.add(const ReportMarkReviewedSubmitted());
      await settle();

      expect(bloc.state, ReportDetailLoaded(detail(), freeze: _open, failure: failure));
      verify(() => repository.getDetail(7)).called(1);
    });
  });

  group('chat evidence — C3 (decision 175): a separate, grant-gated, audited read', () {
    const chat = ReportChatEntity(reportId: 7, tier: 'high', threads: []);

    test('ReportChatRequested loads the chat onto the loaded state (chatLoading in between)',
        () async {
      when(() => repository.getDetail(7)).thenAnswer((_) async => Right(detail()));
      when(() => repository.getFreezeState(7)).thenAnswer((_) async => const Right(_open));
      when(() => repository.getChat(7)).thenAnswer((_) async => const Right(chat));
      final bloc = build()..add(const ReportDetailRequested(7));
      await settle();

      final states = <ReportDetailState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const ReportChatRequested());
      await settle();
      await sub.cancel();

      expect(states, [
        ReportDetailLoaded(detail(), freeze: _open, chatLoading: true),
        ReportDetailLoaded(detail(), freeze: _open, chat: chat),
      ]);
      verify(() => repository.getChat(7)).called(1);
    });

    test('the chat is NEVER fetched with the detail', () async {
      when(() => repository.getDetail(7)).thenAnswer((_) async => Right(detail()));
      when(() => repository.getFreezeState(7)).thenAnswer((_) async => const Right(_open));

      build().add(const ReportDetailRequested(7));
      await settle();

      verifyNever(() => repository.getChat(any(), limit: any(named: 'limit')));
    });

    test('a refused chat (403, no chat_evidence grant) keeps the case with chatFailure',
        () async {
      const failure = Failure(message: 'no', statusCode: 403, code: 'FORBIDDEN');
      when(() => repository.getDetail(7)).thenAnswer((_) async => Right(detail()));
      when(() => repository.getFreezeState(7)).thenAnswer((_) async => const Right(_open));
      when(() => repository.getChat(7)).thenAnswer((_) async => const Left(failure));
      final bloc = build()..add(const ReportDetailRequested(7));
      await settle();

      bloc.add(const ReportChatRequested());
      await settle();

      expect(bloc.state, ReportDetailLoaded(detail(), freeze: _open, chatFailure: failure));
    });

    test('a chat request before a loaded detail is a no-op', () async {
      final bloc = build()..add(const ReportChatRequested());
      await settle();

      expect(bloc.state, const ReportDetailInitial());
      verifyNever(() => repository.getChat(any(), limit: any(named: 'limit')));
    });
  });
}
