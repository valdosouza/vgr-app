import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/geolocator_location_gateway.dart';
import 'data/image_picker_photo_gateway.dart';
import 'data/report_repository_impl.dart';
import 'domain/gateway/location_gateway.dart';
import 'domain/gateway/photo_gateway.dart';
import 'domain/repository/report_repository.dart';
import 'domain/usecase/submit_report_usecase.dart';
import 'presentation/bloc/report_form_bloc.dart';
import 'presentation/page/report_form_page.dart';

class ReportModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<LocationGateway>((i) => const GeolocatorLocationGateway()),
        Bind.lazySingleton<PhotoGateway>((i) => ImagePickerPhotoGateway()),
        Bind.lazySingleton<ReportRepository>(
          (i) => ReportRepositoryImpl(i.get<ApiClient>(), i.get<OfflineQueueService>()),
        ),
        Bind.factory(
          (i) => ReportFormBloc(
            SubmitReportUsecase(i.get<ReportRepository>()),
            i.get<ReportRepository>(),
            i.get<LocationGateway>(),
            i.get<PhotoGateway>(),
          ),
        ),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute(
          '/',
          child: (_, __) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: Modular.get<IdentityBloc>()),
              BlocProvider(create: (_) => Modular.get<ReportFormBloc>()),
            ],
            child: const ReportFormPage(),
          ),
        ),
      ];
}
