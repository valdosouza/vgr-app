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
/// tb_interface of migration 022, each a paged list (decision 220). The
/// assessments screen belongs to L2 (AI pipeline) and doesn't exist yet.
class LegalPolicyModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<LegalPolicyRepository>(
          (i) => LegalPolicyRepositoryImpl(i<ApiClient>()),
        ),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute(
          '/jurisdictions',
          child: (_, __) => BlocProvider<JurisdictionsBloc>(
            create: (_) => JurisdictionsBloc(Modular.get<LegalPolicyRepository>())
              ..add(const RegisterListRequested()),
            child: const LegalJurisdictionsPage(),
          ),
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
        ChildRoute(
          '/capabilities',
          child: (_, __) => BlocProvider<CapabilitiesBloc>(
            create: (_) => CapabilitiesBloc(Modular.get<LegalPolicyRepository>()),
            child: const LegalCapabilitiesPage(),
          ),
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
        // The rules bloc is provided under the factory's base type, the one
        // RegisterScreen looks up; its row actions are RulesBloc's own.
        ChildRoute(
          '/rules',
          child: (_, __) => BlocProvider<RulesRegisterBloc>(
            create: (_) => RulesBloc(Modular.get<LegalPolicyRepository>())
              ..add(const RegisterListRequested()),
            child: const LegalRulesPage(),
          ),
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
      ];
}
