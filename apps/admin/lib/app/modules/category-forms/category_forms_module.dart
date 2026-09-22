import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/category_form_repository_impl.dart';
import 'domain/repository/category_form_repository.dart';
import 'presentation/bloc/category_form_bloc.dart';
import 'presentation/bloc/category_form_event.dart';
import 'presentation/page/category_form_list_page.dart';

class CategoryFormsModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<CategoryFormRepository>(
          (i) => CategoryFormRepositoryImpl(i<ApiClient>()),
        ),
        Bind.factory((i) => CategoryFormBloc(i())),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute(
          '/',
        // The page reads its bloc from the tree (BlocBuilder / context.read),
        // so the ROUTE must provide it — the page tests wrap a provider
        // themselves and never caught this (found live 2026-09-21: every
        // phase-1 screen threw ProviderNotFound on open).
          child: (_, __) => BlocProvider(
            create: (_) => Modular.get<CategoryFormBloc>()..add(const FetchRequested()),
            child: const CategoryFormListPage(),
          ),
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
      ];
}
