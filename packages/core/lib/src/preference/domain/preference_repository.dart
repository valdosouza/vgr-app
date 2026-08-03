import 'package:dartz/dartz.dart';

import '../../error/failure.dart';

/// User preferences persisted on the server (phase 5 — locale lives in
/// tb_user.locale, decision 74). Ported from setes-app's preference feature.
abstract class PreferenceRepository {
  /// The locale tag saved for the session user (e.g. 'pt-BR'), null when
  /// the user never chose one.
  Future<Either<Failure, String?>> getMyLocale();

  Future<Either<Failure, Unit>> saveLocale(String locale);
}
