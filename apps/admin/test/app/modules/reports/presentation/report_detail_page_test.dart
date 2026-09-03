import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/reports/domain/entity/report_entities.dart';
import 'package:vgr_admin/app/modules/reports/domain/repository/reports_repository.dart';
import 'package:vgr_admin/app/modules/reports/presentation/bloc/report_detail_bloc.dart';
import 'package:vgr_admin/app/modules/reports/presentation/page/report_detail_page.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../../helpers/pump_localized.dart';
import '../../../../helpers/session_access.dart';

class MockReportsRepository extends Mock implements ReportsRepository {}

ReportPanelDetailEntity detail({
  bool anonymous = true,
  bool frozen = false,
  bool purged = false,
  bool hidden = false,
  String mediaStatus = 'blocked',
}) =>
    ReportPanelDetailEntity(
      reportId: 7,
      category: purged ? null : 'assault',
      freeTag: purged ? 'noise' : null,
      subject: 'child',
      tier: 'high',
      status: 'open',
      anonymous: anonymous,
      frozen: frozen,
      frozenReason: frozen ? 'Writ 1/2026' : null,
      frozenAt: frozen ? '2026-09-01T11:00:00.000Z' : null,
      purged: purged,
      createdAt: '2026-09-01T10:00:00.000Z',
      resolvedAt: null,
      expiresAt: purged ? null : '2026-12-01T10:00:00.000Z',
      hidden: hidden,
      hiddenReasonCode: hidden ? 'abuse' : null,
      hiddenNote: hidden ? 'threats in the free text' : null,
      hiddenAt: hidden ? '2026-09-02T09:00:00.000Z' : null,
      hiddenBy: hidden ? 4 : null,
      reporter: anonymous ? null : const ReportActorEntity(accountId: 12, displayName: 'Maria'),
      position: purged
          ? null
          : const ReportPositionEntity(lat: -23.55, lng: -46.63, precisionMeters: 1100),
      detailFields: purged ? null : const {'weapon': 'knife'},
      timeline: purged
          ? const []
          : const [
              ReportTimelineEventEntity(
                  eventType: 'created', payload: null, createdAt: '2026-09-01T10:00:00.000Z'),
            ],
      media: purged
          ? const []
          : [
              ReportMediaEntity(
                publicId: 'abc',
                mime: 'image/jpeg',
                width: 800,
                height: 600,
                status: mediaStatus,
                blockedReasonCode: mediaStatus == 'blocked' ? 'illegal_content' : null,
                blockedNote: null,
                blockedAt: mediaStatus == 'blocked' ? '2026-09-02T09:05:00.000Z' : null,
              ),
            ],
      offers: purged
          ? const []
          : const [
              ReportOfferEntity(
                helpOfferId: 1,
                helpType: 'share',
                anonymous: false,
                helper: ReportActorEntity(accountId: 30, displayName: 'João'),
                createdAt: '2026-09-01T12:00:00.000Z',
              ),
              ReportOfferEntity(
                helpOfferId: 2,
                helpType: 'remote_support',
                anonymous: true,
                helper: null,
                createdAt: '2026-09-01T13:00:00.000Z',
              ),
            ],
    );

const _open = ReportFreezeStateEntity(reportId: 7, status: 'open', frozen: false);
const _frozen = ReportFreezeStateEntity(
    reportId: 7, status: 'open', frozen: true, frozenReason: 'Writ 1/2026');
const _frozenPending = ReportFreezeStateEntity(
  reportId: 7,
  status: 'open',
  frozen: true,
  frozenReason: 'Writ 1/2026',
  pendingUnfreeze: ReportPendingUnfreezeEntity(
      reason: 'Closed', requestedBy: 4, requestedAt: '2026-09-02T11:00:00.000Z'),
);

void main() {
  late MockReportsRepository repository;

  setUp(() {
    grantAllPrivileges();
    repository = MockReportsRepository();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await pumpLocalized(
      tester,
      BlocProvider(
        create: (_) => ReportDetailBloc(repository),
        child: const ReportDetailPage(reportId: 7),
      ),
    );
  }

  /// The detail is long; the freeze section sits below the test viewport.
  Future<void> tapVisible(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  void stub({ReportPanelDetailEntity? entity, ReportFreezeStateEntity? freeze = _open}) {
    when(() => repository.getDetail(7)).thenAnswer((_) async => Right(entity ?? detail()));
    when(() => repository.getFreezeState(7)).thenAnswer((_) async => freeze == null
        ? const Left(Failure(message: 'no', statusCode: 403, code: 'FORBIDDEN'))
        : Right(freeze));
  }

  testWidgets('anonymous report: "Anonymous", no account; degraded position with precision; '
      'reveal with the grant shows the exact point and the audit note (159/160)', (tester) async {
    stub();
    when(() => repository.getExactPosition(7)).thenAnswer((_) async =>
        const Right(ReportExactPositionEntity(reportId: 7, lat: -23.5505, lng: -46.6333)));
    await pumpPage(tester);

    expect(find.byKey(const Key('report-reporter-anonymous')), findsOneWidget);
    expect(find.byKey(const Key('report-reporter-identified')), findsNothing);
    expect(find.text('Maria'), findsNothing);
    expect(find.text('≈ -23.550, -46.630'), findsOneWidget);
    expect(find.textContaining('precision ≈ 1100 m'), findsOneWidget);
    expect(find.byKey(const Key('exact-position')), findsNothing);

    await tapVisible(tester, 'reveal-position-button');

    expect(find.byKey(const Key('exact-position')), findsOneWidget);
    expect(find.text('Exact: -23.550500, -46.633300'), findsOneWidget);
    expect(find.text('This read was recorded in the audit trail.'), findsOneWidget);
  });

  testWidgets('without the report_exact_position grant the reveal button does not exist',
      (tester) async {
    SessionAccess.instance.applyPermissions(const {
      'reports': [Privileges.view],
      'case_freeze': [Privileges.view, Privileges.update],
    });
    stub();
    await pumpPage(tester);

    expect(find.byKey(const Key('reveal-position-button')), findsNothing);
    expect(find.text('≈ -23.550, -46.630'), findsOneWidget);
  });

  testWidgets('identified reporter and helpers render as displayName + opaque account id; '
      'anonymous helper stays anonymous; media, timeline and fields listed', (tester) async {
    stub(entity: detail(anonymous: false));
    await pumpPage(tester);

    expect(find.byKey(const Key('report-reporter-identified')), findsOneWidget);
    expect(find.text('Maria'), findsOneWidget);
    expect(find.text('Account #12'), findsOneWidget);
    expect(find.byKey(const Key('report-offer-1')), findsOneWidget);
    expect(find.text('João'), findsOneWidget);
    expect(find.byKey(const Key('report-offer-2')), findsOneWidget);
    expect(find.text('Anonymous helper'), findsOneWidget);
    expect(find.byKey(const Key('report-media-abc')), findsOneWidget);
    expect(find.textContaining('image/jpeg · 800×600 · blocked'), findsOneWidget);
    expect(find.text('Report created'), findsOneWidget);
    expect(find.text('weapon: knife'), findsOneWidget);
  });

  testWidgets('freeze section: mandatory reason via VgrValidators.minLength(3), then the '
      're-fetched state offers step 1; pending offers step 2 (141/141d)', (tester) async {
    stub();
    await pumpPage(tester);

    expect(find.byKey(const Key('report-not-frozen-badge')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('freeze-reason-field')), 'ab');
    await tapVisible(tester, 'freeze-button');
    expect(find.text('Minimum of 3 characters.'), findsOneWidget);
    verifyNever(() => repository.freeze(any(), any()));

    when(() => repository.freeze(7, 'Writ 1/2026')).thenAnswer((_) async => const Right(null));
    stub(entity: detail(frozen: true), freeze: _frozen);
    await tester.enterText(find.byKey(const Key('freeze-reason-field')), 'Writ 1/2026');
    await tapVisible(tester, 'freeze-button');

    expect(find.byKey(const Key('report-frozen-badge')), findsOneWidget);
    expect(find.byKey(const Key('request-unfreeze-button')), findsOneWidget);
    expect(find.byKey(const Key('freeze-button')), findsNothing);

    when(() => repository.requestUnfreeze(7, 'Closed')).thenAnswer((_) async => const Right(null));
    stub(entity: detail(frozen: true), freeze: _frozenPending);
    await tester.enterText(find.byKey(const Key('unfreeze-reason-field')), 'Closed');
    await tapVisible(tester, 'request-unfreeze-button');

    expect(find.byKey(const Key('pending-unfreeze-tile')), findsOneWidget);
    expect(find.byKey(const Key('approve-unfreeze-button')), findsOneWidget);
  });

  testWidgets('a same-user approval renders the server refusal and keeps the case',
      (tester) async {
    stub(entity: detail(frozen: true), freeze: _frozenPending);
    when(() => repository.approveUnfreeze(7)).thenAnswer((_) async => const Left(Failure(
        message: 'The approver must be a different user than the requester',
        statusCode: 422,
        code: 'BUSINESS_RULE')));
    await pumpPage(tester);

    await tapVisible(tester, 'approve-unfreeze-button');

    expect(find.byKey(const Key('report-action-error')), findsOneWidget);
    expect(find.byKey(const Key('approve-unfreeze-button')), findsOneWidget);
  });

  testWidgets('without case_freeze UPDATE the freeze button renders disabled (72)',
      (tester) async {
    SessionAccess.instance.applyPermissions(const {
      'reports': [Privileges.view],
      'case_freeze': [Privileges.view],
    });
    stub();
    await pumpPage(tester);

    expect(tester.widget<VgrPrimaryButton>(find.byKey(const Key('freeze-button'))).onPressed,
        isNull);
  });

  testWidgets('freeze state refused (no case_freeze grant at all): detail still renders, '
      'section says so', (tester) async {
    stub(freeze: null);
    await pumpPage(tester);

    expect(find.byKey(const Key('report-reporter-anonymous')), findsOneWidget);
    expect(find.byKey(const Key('freeze-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('freeze-button')), findsNothing);
  });

  testWidgets('purged skeleton: marker, no position, no reveal', (tester) async {
    stub(entity: detail(purged: true));
    await pumpPage(tester);

    expect(find.byKey(const Key('report-purged-badge')), findsOneWidget);
    expect(find.text('No position available.'), findsOneWidget);
    expect(find.byKey(const Key('reveal-position-button')), findsNothing);
  });

  testWidgets('a 404 renders the lookup error translated by code', (tester) async {
    when(() => repository.getDetail(7)).thenAnswer((_) async => const Left(
        Failure(message: 'gone', statusCode: 404, code: 'NOT_FOUND')));
    when(() => repository.getFreezeState(7)).thenAnswer((_) async => const Right(_open));
    await pumpPage(tester);

    expect(find.byKey(const Key('report-detail-error')), findsOneWidget);
    expect(find.text('Record not found.'), findsOneWidget);
  });

  group('moderation — B2 (decisions 162/163/165/167)', () {
    Future<void> pickReason(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.byKey(const Key('moderation-reason-field')));
      await tester.tap(find.byKey(const Key('moderation-reason-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    testWidgets('not hidden: "Hide report" opens the reason form; `other` without a note '
        'never leaves the screen; a catalog code posts hide(reasonCode) and the re-fetched '
        'case shows the reason label, note, date and Unhide', (tester) async {
      stub();
      await pumpPage(tester);

      expect(find.byKey(const Key('report-hidden-badge')), findsNothing);
      await tapVisible(tester, 'hide-button');
      expect(find.byKey(const Key('moderation-reason-field')), findsOneWidget);

      // Missing reason is REQUIRED (163: the catalog code is mandatory).
      await tapVisible(tester, 'moderation-submit-button');
      expect(find.text('Required field.'), findsOneWidget);

      // `other` demands a note of at least 3 characters (163).
      await pickReason(tester, 'Other');
      await tester.enterText(find.byKey(const Key('moderation-note-field')), 'ab');
      await tapVisible(tester, 'moderation-submit-button');
      expect(find.text('Minimum of 3 characters.'), findsOneWidget);
      verifyNever(() => repository.hide(any(), any(), any()));

      // A catalog code needs no note.
      when(() => repository.hide(7, 'spam', null)).thenAnswer((_) async => const Right(null));
      stub(entity: detail(hidden: true));
      await pickReason(tester, 'Spam');
      await tester.enterText(find.byKey(const Key('moderation-note-field')), '');
      await tapVisible(tester, 'moderation-submit-button');

      verify(() => repository.hide(7, 'spam', null)).called(1);
      expect(find.byKey(const Key('report-hidden-badge')), findsOneWidget);
      expect(find.textContaining('Abuse'), findsOneWidget);
      expect(find.text('threats in the free text'), findsOneWidget);
      expect(find.textContaining('Hidden since 2026-09-02 09:00'), findsOneWidget);
      expect(find.byKey(const Key('unhide-button')), findsOneWidget);
      expect(find.byKey(const Key('hide-button')), findsNothing);
      expect(find.byKey(const Key('moderation-reason-field')), findsNothing);
    });

    testWidgets('unhide uses the SAME form and posts the note with `other` (162: reverting '
        'also needs a reason, one human)', (tester) async {
      stub(entity: detail(hidden: true));
      when(() => repository.unhide(7, 'other', 'Cleared by legal'))
          .thenAnswer((_) async => const Right(null));
      await pumpPage(tester);

      await tapVisible(tester, 'unhide-button');
      await pickReason(tester, 'Other');
      await tester.enterText(
          find.byKey(const Key('moderation-note-field')), 'Cleared by legal');
      stub();
      await tapVisible(tester, 'moderation-submit-button');

      verify(() => repository.unhide(7, 'other', 'Cleared by legal')).called(1);
      expect(find.byKey(const Key('hide-button')), findsOneWidget);
    });

    testWidgets('a blocked media row shows Unblock with its reason and date; an available one '
        'shows Block; the form posts blockMedia(publicId, reasonCode)', (tester) async {
      stub(entity: detail(mediaStatus: 'available'));
      when(() => repository.blockMedia('abc', 'personal_data', null))
          .thenAnswer((_) async => const Right(null));
      await pumpPage(tester);

      expect(find.byKey(const Key('block-media-abc')), findsOneWidget);
      expect(find.byKey(const Key('unblock-media-abc')), findsNothing);

      await tapVisible(tester, 'block-media-abc');
      await pickReason(tester, 'Personal data');
      stub(entity: detail(mediaStatus: 'blocked'));
      await tapVisible(tester, 'moderation-submit-button');

      verify(() => repository.blockMedia('abc', 'personal_data', null)).called(1);
      expect(find.byKey(const Key('unblock-media-abc')), findsOneWidget);
      expect(find.byKey(const Key('block-media-abc')), findsNothing);
      expect(find.textContaining('Blocked since 2026-09-02 09:05'), findsOneWidget);
      expect(find.textContaining('Illegal content'), findsOneWidget);
    });

    testWidgets('cancel closes the form without any call', (tester) async {
      stub();
      await pumpPage(tester);

      await tapVisible(tester, 'hide-button');
      await tapVisible(tester, 'moderation-cancel-button');

      expect(find.byKey(const Key('moderation-reason-field')), findsNothing);
      verifyNever(() => repository.hide(any(), any(), any()));
    });

    testWidgets('without reports UPDATE every moderation button renders disabled (72/165)',
        (tester) async {
      SessionAccess.instance.applyPermissions(const {
        'reports': [Privileges.view],
        'case_freeze': [Privileges.view, Privileges.update],
      });
      stub();
      await pumpPage(tester);

      expect(tester.widget<VgrPrimaryButton>(find.byKey(const Key('hide-button'))).onPressed,
          isNull);
      expect(
          tester.widget<VgrSecondaryButton>(find.byKey(const Key('unblock-media-abc'))).onPressed,
          isNull);
    });

    testWidgets('a server refusal on hide (409 already hidden) renders by code, case kept',
        (tester) async {
      stub();
      when(() => repository.hide(7, 'spam', null)).thenAnswer((_) async => const Left(
          Failure(message: 'already hidden', statusCode: 409, code: 'DUPLICATE')));
      await pumpPage(tester);

      await tapVisible(tester, 'hide-button');
      await pickReason(tester, 'Spam');
      await tapVisible(tester, 'moderation-submit-button');

      expect(find.byKey(const Key('report-action-error')), findsOneWidget);
      expect(find.text('This value already exists.'), findsOneWidget);
      expect(find.byKey(const Key('hide-button')), findsOneWidget);
    });
  });
}
