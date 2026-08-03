import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/user_repository_impl.dart';
import 'domain/entity/user_entity.dart';
import 'presentation/bloc/user_bloc.dart';
import 'presentation/bloc/user_privileges_bloc.dart';
import 'presentation/page/user_page.dart';
import 'presentation/page/user_privileges_page.dart';

class UsersModule extends Module {
  @override
  List<ModularRoute> get routes => [
        ChildRoute(
          '/',
          child: (_, __) => BlocProvider(
            create: (_) => UserBloc(UserRepositoryImpl(Modular.get<ApiClient>()))
              ..add(const UserFetchRequested()),
            child: const UserPage(),
          ),
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
        ChildRoute(
          '/privileges',
          child: (_, args) {
            final user = args.data as UserEntity;
            return BlocProvider(
              create: (_) => UserPrivilegesBloc(UserRepositoryImpl(Modular.get<ApiClient>()))
                ..add(UserPrivilegesFetchRequested(user.id)),
              child: UserPrivilegesPage(user: user),
            );
          },
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
      ];
}
