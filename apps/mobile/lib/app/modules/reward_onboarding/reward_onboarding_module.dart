import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/reward_onboarding_repository_impl.dart';
import 'domain/repository/reward_onboarding_repository.dart';
import 'domain/usecase/get_onboarding_status_usecase.dart';
import 'domain/usecase/submit_onboarding_usecase.dart';
import 'presentation/bloc/reward_onboarding_bloc.dart';
import 'presentation/page/reward_onboarding_page.dart';

class RewardOnboardingModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<RewardOnboardingRepository>(
          (i) => RewardOnboardingRepositoryImpl(i.get<ApiClient>()),
        ),
        Bind.factory((i) => RewardOnboardingBloc(
              GetOnboardingStatusUsecase(i.get<RewardOnboardingRepository>()),
              SubmitOnboardingUsecase(i.get<RewardOnboardingRepository>()),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute(
          '/',
          child: (_, __) => BlocProvider(
            create: (_) => Modular.get<RewardOnboardingBloc>(),
            child: const RewardOnboardingPage(),
          ),
        ),
      ];
}
