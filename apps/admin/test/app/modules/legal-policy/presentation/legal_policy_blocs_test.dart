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

const _brSuspended = JurisdictionEntity(
  code: 'BR',
  name: 'Brazil',
  operationalState: 'suspended',
  isSandbox: false,
);

const _brPending = JurisdictionEntity(
  code: 'BR',
  name: 'Brazil',
  operationalState: 'suspended',
  isSandbox: false,
  pendingState: 'live',
  pendingBy: 7,
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

const _proposal = LegalRuleProposal(
  capability: 'reward.monetary',
  jurisdictionCode: 'BR',
  status: 'blocked',
  reason: 'no_control',
);

PagedResult<T> _page<T>(List<T> items, {int page = 1}) =>
    PagedResult(items: items, page: page, pageSize: 20, total: items.length);

const _sameUser = Failure(
  message: 'The approver must be a different user',
  statusCode: 422,
  code: 'BUSINESS_RULE',
);

/// The Legal Gate blocs on the factory's paged list (PS3 — decision 220):
/// every action is the server's story — signalled to the bridge, then the
/// page reloaded quietly.
void main() {
  late MockLegalPolicyRepository repository;

  setUpAll(() {
    registerFallbackValue(const PagedQuery());
    registerFallbackValue(_proposal);
  });

  setUp(() => repository = MockLegalPolicyRepository());

  group('JurisdictionsBloc', () {
    test('a state change reloads the PAGE — the server owns the semantics (107)', () async {
      var calls = 0;
      when(() => repository.listJurisdictions(any()))
          .thenAnswer((_) async => Right(_page([++calls == 1 ? _brSuspended : _brPending])));
      when(() => repository.requestState('BR', 'live')).thenAnswer((_) async => const Right(_brPending));
      final bloc = JurisdictionsBloc(repository)..add(const RegisterListRequested());
      await bloc.stream.firstWhere((s) => s is RegisterListLoaded<JurisdictionEntity>);

      bloc.add(const JurisdictionStateRequested('BR', 'live'));

      // Loosening became PENDING — known only from the reloaded page.
      await expectLater(
        bloc.stream,
        emits(RegisterListLoaded<JurisdictionEntity>(const PagedQuery(), _page([_brPending]))),
      );
      await bloc.close();
    });

    test('a refused confirm is signalled and the page stays', () async {
      when(() => repository.listJurisdictions(any())).thenAnswer((_) async => Right(_page([_brPending])));
      when(() => repository.confirmState('BR')).thenAnswer((_) async => const Left(_sameUser));
      final bloc = JurisdictionsBloc(repository)..add(const RegisterListRequested());
      await bloc.stream.firstWhere((s) => s is RegisterListLoaded<JurisdictionEntity>);

      bloc.add(const JurisdictionStateConfirmed('BR'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          const RegisterActionFailure<JurisdictionEntity>(_sameUser),
          RegisterListLoaded<JurisdictionEntity>(const PagedQuery(), _page([_brPending])),
        ]),
      );
      await bloc.close();
    });
  });

  group('CapabilitiesBloc', () {
    test('nothing is fetched before a jurisdiction is chosen', () async {
      final bloc = CapabilitiesBloc(repository);

      expect(bloc.state, isA<RegisterListLoaded<CapabilityOverviewEntity>>());
      expect(bloc.jurisdiction, isNull);
      verifyNever(() => repository.listCapabilities(any(), any()));
      await bloc.close();
    });

    test('choosing a jurisdiction loads page 1 of ITS catalog (103)', () async {
      const row = CapabilityOverviewEntity(
        capability: 'report.anonymous',
        description: 'Anonymous reporting',
        module: 'reports',
        effectiveStatus: 'unreviewed',
      );
      when(() => repository.listCapabilities('BR', any())).thenAnswer((_) async => Right(_page([row])));
      final bloc = CapabilitiesBloc(repository)..add(const CapabilitiesJurisdictionChosen('BR'));

      await expectLater(
        bloc.stream,
        emitsThrough(RegisterListLoaded<CapabilityOverviewEntity>(const PagedQuery(), _page([row]))),
      );
      expect(bloc.jurisdiction, 'BR');
      await bloc.close();
    });
  });

  group('RulesBloc', () {
    test('propose is the factory save: signalled, then the page reloads', () async {
      when(() => repository.listRules(any())).thenAnswer((_) async => Right(_page([_rule])));
      when(() => repository.proposeRule(_proposal)).thenAnswer((_) async => const Right(_rule));
      final bloc = RulesBloc(repository)..add(const RegisterListRequested());
      await bloc.stream.firstWhere((s) => s is RegisterListLoaded<LegalRuleEntity>);

      bloc.add(const RegisterNewPressed());
      bloc.add(const RegisterSaveRequested(_proposal));

      await expectLater(
        bloc.stream,
        emitsThrough(const RegisterActionSuccess<LegalRuleEntity>('register.saved')),
      );
      verify(() => repository.proposeRule(_proposal)).called(1);
      await bloc.close();
    });

    test('a same-user approval is signalled and the page stays (107)', () async {
      when(() => repository.listRules(any())).thenAnswer((_) async => Right(_page([_rule])));
      when(() => repository.approveRule(9)).thenAnswer((_) async => const Left(_sameUser));
      final bloc = RulesBloc(repository)..add(const RegisterListRequested());
      await bloc.stream.firstWhere((s) => s is RegisterListLoaded<LegalRuleEntity>);

      bloc.add(const RuleApproved(9));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          const RegisterActionFailure<LegalRuleEntity>(_sameUser),
          RegisterListLoaded<LegalRuleEntity>(const PagedQuery(), _page([_rule])),
        ]),
      );
      await bloc.close();
    });
  });
}
