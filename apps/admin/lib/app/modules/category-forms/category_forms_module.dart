import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/category_form_repository_impl.dart';
import 'domain/repository/category_form_repository.dart';
import 'presentation/bloc/category_form_bloc.dart';
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
          child: (_, __) => const CategoryFormListPage(),
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
      ];
}
