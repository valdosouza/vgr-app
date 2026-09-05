import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../direction_sighting/data/direction_sighting_local_store.dart';
import '../direction_sighting/data/direction_sighting_repository_impl.dart';
import '../direction_sighting/domain/repository/direction_sighting_repository.dart';
import '../direction_sighting/domain/usecase/log_sighting_usecase.dart';
import '../rating/domain/repository/rating_repository.dart';
import '../rating/domain/usecase/rate_offer_usecase.dart';
import 'data/geolocator_location_gateway.dart';
import 'data/image_picker_photo_gateway.dart';
import 'data/my_reports_store.dart';
import 'data/report_repository_impl.dart';
import 'domain/gateway/location_gateway.dart';
import 'domain/gateway/photo_gateway.dart';
import 'domain/repository/report_repository.dart';
import 'domain/usecase/get_report_view_usecase.dart';
import 'domain/usecase/list_nearby_reports_usecase.dart';
import 'domain/usecase/resolve_report_usecase.dart';
import 'domain/usecase/submit_report_usecase.dart';
import 'presentation/bloc/nearby_feed_bloc.dart';
import 'presentation/bloc/report_detail_bloc.dart';
import 'presentation/bloc/report_form_bloc.dart';
import 'presentation/page/nearby_feed_page.dart';
import 'presentation/page/report_detail_page.dart';
import 'presentation/page/report_form_page.dart';

class ReportModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<LocationGateway>((i) => const GeolocatorLocationGateway()),
        Bind.lazySingleton<PhotoGateway>((i) => ImagePickerPhotoGateway()),
        Bind.lazySingleton<ReportRepository>(
          (i) => ReportRepositoryImpl(
            i.get<ApiClient>(),
            i.get<OfflineQueueService>(),
            i.get<MyReportsStore>(),
          ),
        ),
        // DS2 (decisions 200-207): the ONLY consumer is this module's own
        // `ReportDetailBloc` — no other module needs it, so unlike
        // `RatingRepository`/`PanicRepository` this stays module-scoped
        // rather than promoted to `AppModule`. `DirectionSightingLocalStore`
        // itself IS bound at `AppModule` level (see there) because the
        // offline-queue task registration needs it too.
        Bind.lazySingleton<DirectionSightingRepository>(
          (i) => DirectionSightingRepositoryImpl(
            i.get<ApiClient>(),
            i.get<OfflineQueueService>(),
            i.get<DirectionSightingLocalStore>(),
          ),
        ),
        Bind.factory(
          (i) => ReportFormBloc(
            SubmitReportUsecase(i.get<ReportRepository>()),
            i.get<ReportRepository>(),
            i.get<LocationGateway>(),
            i.get<PhotoGateway>(),
          ),
        ),
        Bind.factory(
          (i) => NearbyFeedBloc(
            ListNearbyReportsUsecase(i.get<ReportRepository>()),
            i.get<LocationGateway>(),
          ),
        ),
        Bind.factory(
          (i) => ReportDetailBloc(
            GetReportViewUsecase(i.get<ReportRepository>()),
            i.get<MyReportsStore>(),
            ResolveReportUsecase(i.get<ReportRepository>()),
            RateOfferUsecase(i.get<RatingRepository>()),
            LogSightingUsecase(i.get<DirectionSightingRepository>()),
            i.get<DirectionSightingLocalStore>(),
          ),
        ),
      ];

  @override
  List<ModularRoute> get routes => [
        // The feed is the home; submitting stays one tap away (123).
        ChildRoute(
          '/',
          child: (_, __) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: Modular.get<IdentityBloc>()),
              BlocProvider(create: (_) => Modular.get<NearbyFeedBloc>()),
            ],
            child: const NearbyFeedPage(),
          ),
        ),
        ChildRoute(
          '/new',
          child: (_, __) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: Modular.get<IdentityBloc>()),
              BlocProvider(create: (_) => Modular.get<ReportFormBloc>()),
            ],
            child: const ReportFormPage(),
          ),
        ),
        ChildRoute(
          '/detail/:id',
          child: (_, args) => BlocProvider(
            create: (_) => Modular.get<ReportDetailBloc>(),
            child: ReportDetailPage(
              reportId: int.parse(args.params['id'] as String),
              mediaBaseUrl: Modular.get<ApiClient>().baseUrl,
            ),
          ),
        ),
      ];
}
