import 'package:dartz/dartz.dart';

import '../../error/failure.dart';
import '../../network/api_client.dart';
import '../domain/preference_repository.dart';

class PreferenceRepositoryImpl implements PreferenceRepository {
  PreferenceRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Either<Failure, String?>> getMyLocale() async {
    try {
      final json = await _apiClient.get('/api/core/me');
      final data = json['data'] as Map<String, dynamic>? ?? const {};
      return Right(data['locale'] as String?);
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, Unit>> saveLocale(String locale) async {
    try {
      await _apiClient.put('/api/core/preferences', {'locale': locale});
      return const Right(unit);
    } on Failure catch (f) {
      return Left(f);
    }
  }
}
