import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../rating/domain/repository/rating_repository.dart';
import '../rating/domain/usecase/get_my_reputation_usecase.dart';
import 'data/auth_repository_impl.dart';
import 'data/google_sign_in_gateway.dart';
import 'domain/gateway/social_sign_in_gateway.dart';
import 'domain/repository/auth_repository.dart';
import 'domain/usecase/confirm_email_verification_usecase.dart';
import 'domain/usecase/login_usecase.dart';
import 'domain/usecase/login_with_google_usecase.dart';
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

/// Web-type OAuth client id from Google Cloud Console (decision 152) — the
/// one whose id becomes the ID token's `aud`, which
/// `GOOGLE_OAUTH_CLIENT_ID` on the API checks against. Public, not a
/// secret. TODO: env-configurable like `ApiClient`'s baseUrl below, same
/// treatment once that decision lands.
const _googleServerClientId =
    '74577618050-oan6sgm9bi1vsb5ihp5mbcloqiuktgup.apps.googleusercontent.com';

/// Email+password + Google auth for the app plane (decisions 119/122-124/
/// 151-152). Apple/Facebook and OTP are absent by design — decision 152
/// defers them until real credentials exist.
class AuthModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<AuthRepository>(
          (i) => AuthRepositoryImpl(i.get<ApiClient>()),
        ),
        Bind.lazySingleton<SocialSignInGateway>(
          (i) => GoogleSignInGatewayImpl(serverClientId: _googleServerClientId),
        ),
        Bind.factory((i) => RegisterBloc(
              RegisterUsecase(i.get<AuthRepository>()),
              i.get<IdentityBloc>(),
              i.get<LocalPrefs>(),
            )),
        Bind.factory((i) => LoginBloc(
              LoginUsecase(i.get<AuthRepository>()),
              LoginWithGoogleUsecase(i.get<SocialSignInGateway>(), i.get<AuthRepository>()),
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
              GetMyReputationUsecase(i.get<RatingRepository>()),
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
