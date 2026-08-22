import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/auth_repository_impl.dart';
import 'domain/repository/auth_repository.dart';
import 'domain/usecase/confirm_email_verification_usecase.dart';
import 'domain/usecase/login_usecase.dart';
import 'domain/usecase/register_usecase.dart';
import 'domain/usecase/send_email_verification_usecase.dart';
import 'domain/usecase/sign_out_usecase.dart';
import 'presentation/bloc/account_bloc.dart';
import 'presentation/bloc/email_verification_bloc.dart';
import 'presentation/bloc/login_bloc.dart';
import 'presentation/bloc/register_bloc.dart';
import 'presentation/page/account_page.dart';
import 'presentation/page/email_verification_page.dart';
import 'presentation/page/login_page.dart';
import 'presentation/page/register_page.dart';

/// Email+password auth for the app plane (decisions 119/122-124/151-152).
/// Provider login and OTP are absent by design — decision 152 defers them
/// until real credentials exist.
class AuthModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<AuthRepository>(
          (i) => AuthRepositoryImpl(i.get<ApiClient>()),
        ),
        Bind.factory((i) => RegisterBloc(
              RegisterUsecase(i.get<AuthRepository>()),
              i.get<IdentityBloc>(),
              i.get<LocalPrefs>(),
            )),
        Bind.factory((i) => LoginBloc(
              LoginUsecase(i.get<AuthRepository>()),
              i.get<IdentityBloc>(),
              i.get<LocalPrefs>(),
            )),
        Bind.factory((i) => EmailVerificationBloc(
              SendEmailVerificationUsecase(i.get<AuthRepository>()),
              ConfirmEmailVerificationUsecase(i.get<AuthRepository>()),
            )),
        Bind.factory((i) => AccountBloc(
              SignOutUsecase(i.get<AuthRepository>()),
              i.get<IdentityBloc>(),
              i.get<LocalPrefs>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute(
          '/register/',
          child: (_, __) => BlocProvider(
            create: (_) => Modular.get<RegisterBloc>(),
            child: const RegisterPage(),
          ),
        ),
        ChildRoute(
          '/login/',
          child: (_, __) => BlocProvider(
            create: (_) => Modular.get<LoginBloc>(),
            child: const LoginPage(),
          ),
        ),
        ChildRoute(
          '/verify-email/',
          child: (_, __) => BlocProvider(
            create: (_) => Modular.get<EmailVerificationBloc>(),
            child: const EmailVerificationPage(),
          ),
        ),
        ChildRoute(
          '/account/',
          child: (_, __) => BlocProvider(
            create: (_) => Modular.get<AccountBloc>(),
            child: const AccountPage(),
          ),
        ),
      ];
}
