import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/dual-control-access/domain/entity/dual_control_request_entity.dart';
import 'package:vgr_admin/app/modules/dual-control-access/domain/repository/dual_control_access_repository.dart';
import 'package:vgr_admin/app/modules/dual-control-access/presentation/bloc/dual_control_bloc.dart';
import 'package:vgr_admin/app/modules/dual-control-access/presentation/page/dual_control_access_page.dart';
import 'package:vgr_admin/app/shared/register/register_search_page.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../../helpers/pump_localized.dart';
import '../../../../helpers/session_access.dart';

class MockDualControlAccessRepository extends Mock implements DualControlAccessRepository {}

PagedResult<T> _page<T>(List<T> items) => PagedResult(items: items, page: 1, pageSize: 20, total: items.length);

/// Opened by Ana (7); the signed-in user below is Bia (8) unless a test
/// says otherwise.
const _byAna = DualControlRequestEntity(
  id: 5,
  accountabilityLogEntryId: 1,
  legalBasis: 'Court order #7',
  status: 'pending',
  requestedBy: 7,
  requestedByName: 'Ana',
  createdAt: '2026-10-04T21:38:41.000Z',
);

const _byBia = DualControlRequestEntity(
  id: 6,
  accountabilityLogEntryId: 2,
  legalBasis: 'Emergency #2',
  status: 'pending',
  requestedBy: 8,
  requestedByName: 'Bia',
  createdAt: '2026-10-04T21:45:00.000Z',
);

const _granted = DualControlRequestEntity(
  id: 4,
  accountabilityLogEntryId: 1,
  legalBasis: 'Court order #4',
  status: 'granted',
  requestedBy: 7,
  requestedByName: 'Ana',
  approvedBy: 8,
  approvedByName: 'Bia',
  approvedAt: '2026-10-04T21:40:00.000Z',
  createdAt: '2026-10-04T21:30:00.000Z',
);

const _voided = DualControlRequestEntity(
  id: 1,
  accountabilityLogEntryId: 1,
  legalBasis: 'Court order #1',
  status: 'void',
  createdAt: '2026-09-01T10:00:00.000Z',
);

const _bia = 8;

/// The decision 45 gate on the factory (decisions 223–227): a list, a
/// request form, and "Approve" on the row only for ANOTHER user's pending
/// request.
void main() {
  late MockDualControlAccessRepository repository;

  setUpAll(() {
    registerFallbackValue(const PagedQuery());
    registerFallbackValue(const DualControlRequestDraft(accountabilityLogEntryId: 1, legalBasis: 'x'));
  });

  setUp(() {
    grantAllPrivileges();
    repository = MockDualControlAccessRepository();
  });

  tearDown(revokeAllPrivileges);

  Future<void> pumpPage(WidgetTester tester, {int? sessionUserId = _bia}) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpLocalized(
      tester,
      BlocProvider<DualControlRegisterBloc>(
        create: (_) => DualControlBloc(repository)..add(const RegisterListRequested()),
        child: DualControlAccessPage(sessionUserId: sessionUserId),
      ),
    );
  }

  VgrPrimaryButton approveButton(WidgetTester tester, int id) =>
      tester.widget<VgrPrimaryButton>(find.byKey(Key('dual-control-approve-$id')));

  testWidgets('rows show status, legal basis and the people by NAME (227)', (tester) async {
    when(() => repository.list(any())).thenAnswer((_) async => Right(_page([_byAna, _granted, _voided])));
    await pumpPage(tester);

    expect(find.text('Request #5 · log entry #1'), findsOneWidget);
    expect(find.text('Court order #7'), findsOneWidget);
    expect(find.text('Requested by Ana on ${formatLocalDateTime(_byAna.createdAt)}'), findsOneWidget);
    expect(find.text('Awaiting approval'), findsOneWidget);
    expect(find.text('Approved by Bia on ${formatLocalDateTime(_granted.approvedAt)}'), findsOneWidget);
    expect(find.text('Granted'), findsOneWidget);
    // A voided pre-fix request: no requester, a dash — never an e-mail.
    expect(find.text('Requested by — on ${formatLocalDateTime(_voided.createdAt)}'), findsOneWidget);
    expect(find.textContaining('Voided'), findsOneWidget);
    // Only a pending request offers the action.
    expect(find.byKey(const Key('dual-control-approve-5')), findsOneWidget);
    expect(find.byKey(const Key('dual-control-approve-4')), findsNothing);
    expect(find.byKey(const Key('dual-control-approve-1')), findsNothing);
  });

  testWidgets('Approve is disabled on the request you opened — another person must approve (224)',
      (tester) async {
    when(() => repository.list(any())).thenAnswer((_) async => Right(_page([_byAna, _byBia])));
    await pumpPage(tester);

    expect(approveButton(tester, 6).onPressed, isNull);
    expect(find.byKey(const Key('dual-control-own-6')), findsOneWidget);
    expect(find.text('You opened this request — another person must approve it.'), findsOneWidget);
    expect(approveButton(tester, 5).onPressed, isNotNull);
    expect(find.byKey(const Key('dual-control-own-5')), findsNothing);
  });

  testWidgets('approving another user\'s request goes to the API and reloads with its answer',
      (tester) async {
    var calls = 0;
    when(() => repository.list(any())).thenAnswer(
      (_) async => Right(_page([calls++ == 0 ? _byAna : _granted.copyWithIdOf(_byAna)])),
    );
    when(() => repository.approve(5)).thenAnswer((_) async => Right(_granted.copyWithIdOf(_byAna)));
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('dual-control-approve-5')));
    await tester.pumpAndSettle();

    verify(() => repository.approve(5)).called(1);
    expect(find.text('Request approved — access granted.'), findsOneWidget);
    expect(find.text('Approved by Bia on ${formatLocalDateTime(_granted.approvedAt)}'), findsOneWidget);
    expect(find.byKey(const Key('dual-control-approve-5')), findsNothing);
  });

  testWidgets('a refused approval (lost to a simultaneous one) arrives through the bridge; the list stays',
      (tester) async {
    when(() => repository.list(any())).thenAnswer((_) async => Right(_page([_byAna])));
    when(() => repository.approve(5)).thenAnswer((_) async => const Left(Failure(
          message: 'Request is not awaiting approval',
          statusCode: 409,
          code: 'BUSINESS_RULE',
        )));
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('dual-control-approve-5')));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byKey(const Key('dual-control-status-5')), findsOneWidget);
  });

  testWidgets('without the approver resource Approve stays disabled (45/93)', (tester) async {
    SessionAccess.instance.applyPermissions({
      'dual_control_access': const [Privileges.view, Privileges.insert, Privileges.update],
    });
    when(() => repository.list(any())).thenAnswer((_) async => Right(_page([_byAna])));
    await pumpPage(tester);

    expect(approveButton(tester, 5).onPressed, isNull);
  });

  testWidgets('without INSERT there is no "new"; rows never open', (tester) async {
    SessionAccess.instance.applyPermissions({
      'dual_control_access': const [Privileges.view],
    });
    when(() => repository.list(any())).thenAnswer((_) async => Right(_page([_byAna])));
    await pumpPage(tester);

    expect(find.byKey(RegisterSearchPage.newButtonKey), findsNothing);
    await tester.tap(find.byKey(RegisterSearchPage.rowKey(5)));
    await tester.pumpAndSettle();
    expect(find.byKey(VgrFormShell.saveKey), findsNothing);
  });

  testWidgets('the request form mirrors the DTO and sends what is asked and why — no approver field',
      (tester) async {
    when(() => repository.list(any())).thenAnswer((_) async => Right(_page(const <DualControlRequestEntity>[])));
    when(() => repository.request(any())).thenAnswer((_) async => const Right(_byBia));
    await pumpPage(tester);

    await tester.tap(find.byKey(RegisterSearchPage.newButtonKey));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('register-field-approverId')), findsNothing);

    // The number field already keeps digits only; zero is what still
    // reaches the DTO mirror (z.number().int().positive()).
    await tester.enterText(find.byKey(const Key('register-field-accountabilityLogEntryId')), '0');
    await tester.enterText(find.byKey(const Key('register-field-legalBasis')), '  Emergency #2  ');
    await tester.tap(find.byKey(VgrFormShell.saveKey));
    await tester.pumpAndSettle();
    expect(find.text('Accountability log entry id: Invalid value.'), findsOneWidget);
    verifyNever(() => repository.request(any()));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('register-field-accountabilityLogEntryId')), '2');
    await tester.tap(find.byKey(VgrFormShell.saveKey));
    await tester.pumpAndSettle();

    final sent = verify(() => repository.request(captureAny())).captured.single as DualControlRequestDraft;
    expect(sent, const DualControlRequestDraft(accountabilityLogEntryId: 2, legalBasis: 'Emergency #2'));
  });

  testWidgets('an unknown session user leaves Approve to the API (it still refuses the requester)',
      (tester) async {
    when(() => repository.list(any())).thenAnswer((_) async => Right(_page([_byBia])));
    await pumpPage(tester, sessionUserId: null);

    expect(approveButton(tester, 6).onPressed, isNotNull);
  });
}

extension on DualControlRequestEntity {
  /// The same request after its approval, keeping the pending row's id.
  DualControlRequestEntity copyWithIdOf(DualControlRequestEntity pending) => DualControlRequestEntity(
        id: pending.id,
        accountabilityLogEntryId: pending.accountabilityLogEntryId,
        legalBasis: pending.legalBasis,
        status: status,
        requestedBy: pending.requestedBy,
        requestedByName: pending.requestedByName,
        approvedBy: approvedBy,
        approvedByName: approvedByName,
        approvedAt: approvedAt,
        createdAt: pending.createdAt,
      );
}
