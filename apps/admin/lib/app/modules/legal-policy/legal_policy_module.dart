import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/legal_policy_repository_impl.dart';
import 'domain/repository/legal_policy_repository.dart';
import 'presentation/bloc/capabilities_bloc.dart';
import 'presentation/bloc/jurisdictions_bloc.dart';
import 'presentation/bloc/rules_bloc.dart';
import 'presentation/page/legal_capabilities_page.dart';
import 'presentation/page/legal_jurisdictions_page.dart';
import 'presentation/page/legal_rules_page.dart';

/// Legal Gate admin screens (plan L3, decisions 103-109) — one screen per
/// tb_interface of migration 022. The assessments screen belongs to L2
/// (AI pipeline) and doesn't exist yet.
class LegalPolicyModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<LegalPolicyRepository>(
          (i) => LegalPolicyRepositoryImpl(i<ApiClient>()),
        ),
        Bind.factory((i) => JurisdictionsBloc(i())),
        Bind.factory((i) => CapabilitiesBloc(i())),
        Bind.factory((i) => RulesBloc(i())),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute(
          '/jurisdictions',
          child: (_, __) => BlocProvider(
            create: (_) => Modular.get<JurisdictionsBloc>(),
            child: const LegalJurisdictionsPage(),
          ),
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
        ChildRoute(
          '/capabilities',
          child: (_, __) => BlocProvider(
            create: (_) => Modular.get<CapabilitiesBloc>(),
            child: const LegalCapabilitiesPage(),
          ),
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
        ChildRoute(
          '/rules',
          child: (_, __) => BlocProvider(
            create: (_) => Modular.get<RulesBloc>(),
            child: const LegalRulesPage(),
          ),
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
      ];
}
