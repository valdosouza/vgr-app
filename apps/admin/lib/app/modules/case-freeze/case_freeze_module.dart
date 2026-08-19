import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/case_freeze_repository_impl.dart';
import 'domain/repository/case_freeze_repository.dart';
import 'presentation/bloc/case_freeze_bloc.dart';
import 'presentation/page/case_freeze_page.dart';

class CaseFreezeModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<CaseFreezeRepository>(
          (i) => CaseFreezeRepositoryImpl(i<ApiClient>()),
        ),
        Bind.factory((i) => CaseFreezeBloc(i())),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute(
          '/',
          child: (_, __) => BlocProvider(
            create: (_) => Modular.get<CaseFreezeBloc>(),
            child: const CaseFreezePage(),
          ),
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
      ];
}
