import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/legal-policy/domain/entity/legal_policy_entities.dart';
import 'package:vgr_admin/app/modules/legal-policy/domain/repository/legal_policy_repository.dart';
import 'package:vgr_admin/app/modules/legal-policy/presentation/bloc/capabilities_bloc.dart';
import 'package:vgr_admin/app/modules/legal-policy/presentation/bloc/jurisdictions_bloc.dart';
import 'package:vgr_admin/app/modules/legal-policy/presentation/bloc/rules_bloc.dart';
import 'package:vgr_admin/app/modules/legal-policy/presentation/page/legal_capabilities_page.dart';
import 'package:vgr_admin/app/modules/legal-policy/presentation/page/legal_jurisdictions_page.dart';
import 'package:vgr_admin/app/modules/legal-policy/presentation/page/legal_rules_page.dart';
import 'package:vgr_admin/app/shared/register/register_search_page.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../../helpers/pump_localized.dart';
import '../../../../helpers/session_access.dart';

class MockLegalPolicyRepository extends Mock implements LegalPolicyRepository {}

PagedResult<T> _page<T>(List<T> items) =>
    PagedResult(items: items, page: 1, pageSize: 20, total: items.length);

const _brPending = JurisdictionEntity(
  code: 'BR',
  name: 'Brazil',
  operationalState: 'suspended',
  isSandbox: false,
  pendingState: 'live',
  pendingBy: 7,
);

const _proposed = LegalRuleEntity(
  id: 9,
  capability: 'reward.monetary',
  jurisdictionCode: 'BR',
  version: 1,
  status: 'blocked',
  reason: 'no_control',
  reviewState: 'none',
  ruleState: 'proposed',
  proposedBy: 7,
);

/// The Legal Gate screens on the factory's paged list (PS3 — decisions
/// 103-109, 220, 221).
void main() {
  late MockLegalPolicyRepository repository;

  setUpAll(() {
    registerFallbackValue(const PagedQuery());
    registerFallbackValue(const LegalRuleProposal(
      capability: 'x.y',
      jurisdictionCode: 'BR',
      status: 'allowed',
    ));
  });

  setUp(() {
    grantAllPrivileges();
    repository = MockLegalPolicyRepository();
  });

  tearDown(revokeAllPrivileges);

  Future<void> pumpAt(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpLocalized(tester, page);
  }

  Future<void> pumpJurisdictions(WidgetTester tester) => pumpAt(
        tester,
        BlocProvider<JurisdictionsBloc>(
          create: (_) => JurisdictionsBloc(repository)..add(const RegisterListRequested()),
          child: const LegalJurisdictionsPage(),
        ),
      );

  Future<void> pumpRules(WidgetTester tester) => pumpAt(
        tester,
        BlocProvider<RulesRegisterBloc>(
          create: (_) => RulesBloc(repository)..add(const RegisterListRequested()),
          child: const LegalRulesPage(),
        ),
      );

  group('LegalJurisdictionsPage', () {
    testWidgets('a pending loosening renders who proposed it and the confirm action (107)',
        (tester) async {
      when(() => repository.listJurisdictions(any())).thenAnswer((_) async => Right(_page([_brPending])));
      await pumpJurisdictions(tester);

      expect(find.byKey(const Key('jurisdiction-pending-BR')), findsOneWidget);
      expect(find.byKey(VgrSearchBar.fieldKey), findsOneWidget);

      when(() => repository.confirmState('BR')).thenAnswer((_) async => const Right(
          JurisdictionEntity(code: 'BR', name: 'Brazil', operationalState: 'live', isSandbox: false)));
      when(() => repository.listJurisdictions(any())).thenAnswer((_) async => Right(_page(const [
            JurisdictionEntity(code: 'BR', name: 'Brazil', operationalState: 'live', isSandbox: false),
          ])));

      await tester.tap(find.byKey(const Key('jurisdiction-confirm-BR')));
      await tester.pumpAndSettle();

      verify(() => repository.confirmState('BR')).called(1);
      expect(find.byKey(const Key('jurisdiction-pending-BR')), findsNothing);
    });

    testWidgets('a refused confirm reaches the user through the bridge; the row stays', (tester) async {
      when(() => repository.listJurisdictions(any())).thenAnswer((_) async => Right(_page([_brPending])));
      when(() => repository.confirmState('BR')).thenAnswer((_) async => const Left(Failure(
            message: 'The confirmer must be a different user',
            statusCode: 422,
            code: 'BUSINESS_RULE',
          )));
      await pumpJurisdictions(tester);

      await tester.tap(find.byKey(const Key('jurisdiction-confirm-BR')));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byKey(const Key('jurisdiction-pending-BR')), findsOneWidget);
    });

    testWidgets('without dual_control_approval the confirm renders disabled (layered guards, 93)',
        (tester) async {
      SessionAccess.instance.applyPermissions(const {
        'legal_jurisdictions': [Privileges.view, Privileges.update],
        // no dual_control_approval
      });
      when(() => repository.listJurisdictions(any())).thenAnswer((_) async => Right(_page([_brPending])));
      await pumpJurisdictions(tester);

      final button = tester.widget<VgrPrimaryButton>(find.byKey(const Key('jurisdiction-confirm-BR')));
      expect(button.onPressed, isNull);
    });

    testWidgets('the filter asks the API for page 1 of the matching jurisdictions', (tester) async {
      when(() => repository.listJurisdictions(any())).thenAnswer((_) async => Right(_page([_brPending])));
      await pumpJurisdictions(tester);

      await tester.enterText(find.byKey(VgrSearchBar.fieldKey), 'bra');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      verify(() => repository.listJurisdictions(const PagedQuery(filter: 'bra'))).called(1);
    });
  });

  group('LegalCapabilitiesPage', () {
    testWidgets('asks for a jurisdiction first; unreviewed renders as the block it is (L1)',
        (tester) async {
      when(() => repository.listCapabilities('BR', any())).thenAnswer((_) async => Right(_page(const [
            CapabilityOverviewEntity(
              capability: 'reward.monetary',
              description: 'Monetary reward',
              module: 'reward',
              effectiveStatus: 'unreviewed',
            ),
          ])));
      await pumpAt(
        tester,
        BlocProvider<CapabilitiesBloc>(
          create: (_) => CapabilitiesBloc(repository),
          child: const LegalCapabilitiesPage(),
        ),
      );

      expect(find.byKey(RegisterSearchPage.emptyKey), findsOneWidget);
      verifyNever(() => repository.listCapabilities(any(), any()));

      await tester.enterText(find.byKey(const Key('capabilities-jurisdiction-field')), 'br');
      await tester.tap(find.byKey(const Key('capabilities-load-button')));
      await tester.pumpAndSettle();

      // Lowercase input reaches the API uppercased, on page 1.
      verify(() => repository.listCapabilities('BR', const PagedQuery())).called(1);
      expect(find.textContaining('Unreviewed (blocks in production)'), findsOneWidget);
    });
  });

  group('LegalRulesPage', () {
    testWidgets('proposing a blocked rule requires and carries the typified reason (78)', (tester) async {
      when(() => repository.listRules(any())).thenAnswer((_) async => Right(_page(const <LegalRuleEntity>[])));
      when(() => repository.proposeRule(any())).thenAnswer((_) async => const Right(_proposed));
      await pumpRules(tester);

      await tester.tap(find.byKey(RegisterSearchPage.newButtonKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('register-field-capability')), 'reward.monetary');
      await tester.enterText(find.byKey(const Key('register-field-jurisdictionCode')), 'br');
      // Status starts 'allowed'; choosing blocked brings the reason in.
      expect(find.byKey(const Key('register-field-reason')), findsNothing);
      await tester.tap(find.byKey(const Key('register-field-status')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blocked').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(VgrFormShell.saveKey));
      await tester.pumpAndSettle();
      expect(find.textContaining('Required field.'), findsOneWidget);
      verifyNever(() => repository.proposeRule(any()));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('register-field-reason')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No control in the product').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(VgrFormShell.saveKey));
      await tester.pumpAndSettle();

      final sent = verify(() => repository.proposeRule(captureAny())).captured.single as LegalRuleProposal;
      expect(sent.jurisdictionCode, 'BR');
      expect(sent.status, 'blocked');
      expect(sent.reason, 'no_control');
    });

    testWidgets('rows never open; a proposed row offers approve/reject', (tester) async {
      when(() => repository.listRules(any())).thenAnswer((_) async => Right(_page([_proposed])));
      await pumpRules(tester);

      expect(find.byKey(const Key('rule-approve-9')), findsOneWidget);
      expect(find.byKey(const Key('rule-reject-9')), findsOneWidget);
      await tester.tap(find.byKey(RegisterSearchPage.rowKey(9)));
      await tester.pumpAndSettle();
      expect(find.byKey(VgrFormShell.saveKey), findsNothing);
    });

    testWidgets('a same-user approval reaches the user through the bridge; the list stays',
        (tester) async {
      when(() => repository.listRules(any())).thenAnswer((_) async => Right(_page([_proposed])));
      when(() => repository.approveRule(9)).thenAnswer((_) async => const Left(Failure(
            message: 'The approver must be a different user',
            statusCode: 422,
            code: 'BUSINESS_RULE',
          )));
      await pumpRules(tester);

      await tester.tap(find.byKey(const Key('rule-approve-9')));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byKey(const Key('rule-summary-9')), findsOneWidget);
    });
  });
}
