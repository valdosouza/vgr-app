import 'package:dartz/dartz.dart';

import '../../error/failure.dart';
import '../../network/api_client.dart';
import '../domain/current_user.dart';
import '../domain/current_user_repository.dart';

class CurrentUserRepositoryImpl implements CurrentUserRepository {
  CurrentUserRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Either<Failure, CurrentUser>> getMe() async {
    try {
      final json = await _apiClient.get('/api/core/me');
      final data = (json['data'] as Map?)?.cast<String, dynamic>() ?? const {};
      return Right(CurrentUser.fromJson(data));
    } on Failure catch (f) {
      return Left(f);
    }
  }
}
