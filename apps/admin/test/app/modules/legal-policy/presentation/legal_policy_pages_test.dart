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
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../../helpers/pump_localized.dart';
import '../../../../helpers/session_access.dart';

class MockLegalPolicyRepository extends Mock implements LegalPolicyRepository {}

void main() {
  late MockLegalPolicyRepository repository;

  setUp(() {
    grantAllPrivileges();
    repository = MockLegalPolicyRepository();
    registerFallbackValue(const LegalRuleProposal(
      capability: 'x.y',
      jurisdictionCode: 'BR',
      status: 'allowed',
    ));
  });

  group('LegalJurisdictionsPage', () {
    testWidgets('a pending loosening renders who proposed it and the confirm '
        'action (107)', (tester) async {
      when(() => repository.listJurisdictions()).thenAnswer((_) async =>
          const Right([
            JurisdictionEntity(
                code: 'BR',
                name: 'Brazil',
                operationalState: 'suspended',
                isSandbox: false,
                pendingState: 'live',
                pendingBy: 7),
          ]));

      await pumpLocalized(
        tester,
        BlocProvider(
          create: (_) => JurisdictionsBloc(repository),
          child: const LegalJurisdictionsPage(),
        ),
      );

      expect(find.byKey(const Key('jurisdiction-pending-BR')), findsOneWidget);

      when(() => repository.confirmState('BR')).thenAnswer((_) async =>
          const Right(JurisdictionEntity(
              code: 'BR',
              name: 'Brazil',
              operationalState: 'live',
              isSandbox: false)));
      when(() => repository.listJurisdictions()).thenAnswer((_) async =>
          const Right([
            JurisdictionEntity(
                code: 'BR',
                name: 'Brazil',
                operationalState: 'live',
                isSandbox: false),
          ]));

      await tester.tap(find.byKey(const Key('jurisdiction-confirm-BR')));
      await tester.pumpAndSettle();

      verify(() => repository.confirmState('BR')).called(1);
      expect(find.byKey(const Key('jurisdiction-pending-BR')), findsNothing);
    });

    testWidgets('without dual_control_approval the confirm renders disabled '
        '(layered guards, decision 93)', (tester) async {
      SessionAccess.instance.applyPermissions(const {
        'legal_jurisdictions': [Privileges.view, Privileges.update],
        // no dual_control_approval
      });
      when(() => repository.listJurisdictions()).thenAnswer((_) async =>
          const Right([
            JurisdictionEntity(
                code: 'BR',
                name: 'Brazil',
                operationalState: 'suspended',
                isSandbox: false,
                pendingState: 'live',
                pendingBy: 7),
          ]));

      await pumpLocalized(
        tester,
        BlocProvider(
          create: (_) => JurisdictionsBloc(repository),
          child: const LegalJurisdictionsPage(),
        ),
      );

      final button = tester.widget<VgrPrimaryButton>(
          find.byKey(const Key('jurisdiction-confirm-BR')));
      expect(button.onPressed, isNull);
    });
  });

  group('LegalCapabilitiesPage', () {
    testWidgets('unreviewed renders as the block it is in production (L1)',
        (tester) async {
      when(() => repository.listCapabilities('BR')).thenAnswer((_) async =>
          const Right([
            CapabilityOverviewEntity(
                capability: 'reward.monetary',
                description: 'Monetary reward',
                module: 'reward',
                effectiveStatus: 'unreviewed'),
          ]));

      await pumpLocalized(
        tester,
        BlocProvider(
          create: (_) => CapabilitiesBloc(repository),
          child: const LegalCapabilitiesPage(),
        ),
      );

      await tester.enterText(
          find.byKey(const Key('capabilities-jurisdiction-field')), 'br');
      await tester.tap(find.byKey(const Key('capabilities-load-button')));
      await tester.pumpAndSettle();

      // Lowercase input reaches the API uppercased.
      verify(() => repository.listCapabilities('BR')).called(1);
      expect(
          find.textContaining('Unreviewed (blocks in production)'), findsOneWidget);
    });
  });

  group('LegalRulesPage', () {
    testWidgets('proposing a blocked rule carries the typified reason (78) '
        'and the proposed row offers approve/reject', (tester) async {
      when(() => repository.listRules(capability: null, jurisdiction: null))
          .thenAnswer((_) async => const Right(<LegalRuleEntity>[]));

      await pumpLocalized(
        tester,
        BlocProvider(
          create: (_) => RulesBloc(repository),
          child: const LegalRulesPage(),
        ),
      );

      const proposed = LegalRuleEntity(
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
      when(() => repository.proposeRule(any()))
          .thenAnswer((_) async => const Right(proposed));
      when(() => repository.listRules(capability: null, jurisdiction: null))
          .thenAnswer((_) async => const Right([proposed]));

      await tester.enterText(
          find.byKey(const Key('rule-capability-field')), 'reward.monetary');
      await tester.enterText(
          find.byKey(const Key('rule-jurisdiction-field')), 'br');
      // Status starts 'allowed'; choose blocked so the reason field appears.
      await tester.tap(find.byKey(const Key('rule-status-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blocked').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('rule-reason-field')), findsOneWidget);

      await tester.tap(find.byKey(const Key('rule-propose-button')));
      await tester.pumpAndSettle();

      final sent = verify(() => repository.proposeRule(captureAny()))
          .captured
          .single as LegalRuleProposal;
      expect(sent.jurisdictionCode, 'BR');
      expect(sent.status, 'blocked');
      expect(sent.reason, 'no_control');

      expect(find.byKey(const Key('rule-approve-9')), findsOneWidget);
      expect(find.byKey(const Key('rule-reject-9')), findsOneWidget);
    });

    testWidgets('a same-user approval renders the refusal and keeps the list',
        (tester) async {
      const proposed = LegalRuleEntity(
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
      when(() => repository.listRules(capability: null, jurisdiction: null))
          .thenAnswer((_) async => const Right([proposed]));
      when(() => repository.approveRule(9)).thenAnswer((_) async => const Left(
          Failure(
              message: 'The approver must be a different user',
              statusCode: 422,
              code: 'BUSINESS_RULE')));

      await pumpLocalized(
        tester,
        BlocProvider(
          create: (_) => RulesBloc(repository),
          child: const LegalRulesPage(),
        ),
      );

      await tester.ensureVisible(find.byKey(const Key('rule-approve-9')));
      await tester.tap(find.byKey(const Key('rule-approve-9')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('rules-action-error')), findsOneWidget);
      expect(find.byKey(const Key('rule-summary-9')), findsOneWidget);
    });
  });
}
