import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../shared/data/my_reports_store.dart';
import 'data/help_offer_repository_impl.dart';
import 'domain/repository/help_offer_repository.dart';
import 'domain/usecase/submit_help_offer_usecase.dart';
import 'presentation/bloc/help_offer_bloc.dart';
import 'presentation/page/help_offer_form_page.dart';

class HelpOfferModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<HelpOfferRepository>(
          (i) => HelpOfferRepositoryImpl(i.get<ApiClient>()),
        ),
        Bind.factory((i) {
          // Ownership = clientKey possession (decisions 20/134, amendment
          // MA8): the same store the report module writes on submit
          // answers whether this device is the case's reporter.
          Future<bool> ownsReport(int reportId) async =>
              await i.get<MyReportsStore>().clientKeyOf(reportId) != null;
          return HelpOfferBloc(
            SubmitHelpOfferUsecase(i.get<HelpOfferRepository>(),
                ownsReport: ownsReport),
            ownsReport: ownsReport,
          );
        }),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute(
          '/:id',
          child: (_, args) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: Modular.get<IdentityBloc>()),
              BlocProvider(create: (_) => Modular.get<HelpOfferBloc>()),
            ],
            child: HelpOfferFormPage(
              reportId: int.parse(args.params['id'] as String),
            ),
          ),
        ),
      ];
}
