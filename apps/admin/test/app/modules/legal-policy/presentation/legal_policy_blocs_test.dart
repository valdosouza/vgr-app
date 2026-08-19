import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/legal-policy/domain/entity/legal_policy_entities.dart';
import 'package:vgr_admin/app/modules/legal-policy/domain/repository/legal_policy_repository.dart';
import 'package:vgr_admin/app/modules/legal-policy/presentation/bloc/capabilities_bloc.dart';
import 'package:vgr_admin/app/modules/legal-policy/presentation/bloc/jurisdictions_bloc.dart';
import 'package:vgr_admin/app/modules/legal-policy/presentation/bloc/rules_bloc.dart';

class MockLegalPolicyRepository extends Mock implements LegalPolicyRepository {}

const _br = JurisdictionEntity(
  code: 'BR',
  name: 'Brazil',
  operationalState: 'live',
  isSandbox: false,
);
const _rule = LegalRuleEntity(
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

void main() {
  late MockLegalPolicyRepository repository;

  setUp(() {
    repository = MockLegalPolicyRepository();
    registerFallbackValue(const LegalRuleProposal(
      capability: 'x.y',
      jurisdictionCode: 'BR',
      status: 'allowed',
    ));
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('JurisdictionsBloc', () {
    test('a state change reloads the LIST — the server owns the semantics '
        '(107: tighten now, loosen pending)', () async {
      when(() => repository.listJurisdictions())
          .thenAnswer((_) async => const Right([_br]));
      final bloc = JurisdictionsBloc(repository)
        ..add(const JurisdictionsRequested());
      await settle();

      when(() => repository.requestState('BR', 'suspended')).thenAnswer(
          (_) async => const Right(_br)); // response row is NOT trusted
      when(() => repository.listJurisdictions()).thenAnswer((_) async =>
          const Right([
            JurisdictionEntity(
                code: 'BR',
                name: 'Brazil',
                operationalState: 'suspended',
                isSandbox: false)
          ]));

      bloc.add(const JurisdictionStateRequested('BR', 'suspended'));
      await settle();

      final loaded = bloc.state as JurisdictionsLoaded;
      expect(loaded.rows.single.operationalState, 'suspended');
    });

    test('a refused confirm keeps the list with the failure attached', () async {
      when(() => repository.listJurisdictions())
          .thenAnswer((_) async => const Right([_br]));
      final bloc = JurisdictionsBloc(repository)
        ..add(const JurisdictionsRequested());
      await settle();

      const failure = Failure(
          message: 'The confirmer must be a different user',
          statusCode: 422,
          code: 'BUSINESS_RULE');
      when(() => repository.confirmState('BR'))
          .thenAnswer((_) async => const Left(failure));

      bloc.add(const JurisdictionStateConfirmed('BR'));
      await settle();

      final loaded = bloc.state as JurisdictionsLoaded;
      expect(loaded.failure, failure);
      expect(loaded.rows, const [_br]);
    });
  });

  group('CapabilitiesBloc', () {
    test('loads the catalog for the requested jurisdiction', () async {
      when(() => repository.listCapabilities('BR')).thenAnswer((_) async =>
          const Right([
            CapabilityOverviewEntity(
                capability: 'report.anonymous',
                description: 'Anonymous reporting',
                module: 'reports',
                effectiveStatus: 'unreviewed')
          ]));

      final bloc = CapabilitiesBloc(repository)
        ..add(const CapabilitiesRequested('BR'));
      await settle();

      final loaded = bloc.state as CapabilitiesLoaded;
      expect(loaded.jurisdiction, 'BR');
      expect(loaded.rows.single.effectiveStatus, 'unreviewed');
    });
  });

  group('RulesBloc', () {
    test('propose reloads under the current filter', () async {
      when(() => repository.listRules(capability: 'reward.monetary', jurisdiction: 'BR'))
          .thenAnswer((_) async => const Right(<LegalRuleEntity>[]));
      final bloc = RulesBloc(repository)
        ..add(const RulesRequested(
            capability: 'reward.monetary', jurisdiction: 'BR'));
      await settle();

      when(() => repository.proposeRule(any()))
          .thenAnswer((_) async => const Right(_rule));
      when(() => repository.listRules(capability: 'reward.monetary', jurisdiction: 'BR'))
          .thenAnswer((_) async => const Right([_rule]));

      bloc.add(const RuleProposed(LegalRuleProposal(
        capability: 'reward.monetary',
        jurisdictionCode: 'BR',
        status: 'blocked',
        reason: 'no_control',
      )));
      await settle();

      expect((bloc.state as RulesLoaded).rows.single.ruleState, 'proposed');
    });

    test('a same-user approval keeps the list and carries the refusal (107)',
        () async {
      when(() => repository.listRules(capability: null, jurisdiction: null))
          .thenAnswer((_) async => const Right([_rule]));
      final bloc = RulesBloc(repository)..add(const RulesRequested());
      await settle();

      const failure = Failure(
          message: 'The approver must be a different user',
          statusCode: 422,
          code: 'BUSINESS_RULE');
      when(() => repository.approveRule(9))
          .thenAnswer((_) async => const Left(failure));

      bloc.add(const RuleApproved(9));
      await settle();

      final loaded = bloc.state as RulesLoaded;
      expect(loaded.failure, failure);
      expect(loaded.rows.single.id, 9);
    });
  });
}
