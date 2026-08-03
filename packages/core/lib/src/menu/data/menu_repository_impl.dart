import 'package:dartz/dartz.dart';

import '../../error/failure.dart';
import '../../network/api_client.dart';
import '../domain/menu_entity.dart';
import '../domain/menu_repository.dart';

class MenuRepositoryImpl implements MenuRepository {
  MenuRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Either<Failure, List<MenuModule>>> getMenus() async {
    try {
      final json = await _apiClient.get('/api/core/menus');
      final data = json['data'] as List<dynamic>? ?? const [];
      return Right(
        data.map((m) => MenuModule.fromJson(m as Map<String, dynamic>)).toList(),
      );
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, Map<String, List<String>>>> getPermissions() async {
    try {
      final json = await _apiClient.get('/api/core/permissions');
      final data = json['data'] as Map<String, dynamic>? ?? const {};
      return Right(data.map(
        (key, value) => MapEntry(key, (value as List<dynamic>).cast<String>()),
      ));
    } on Failure catch (f) {
      return Left(f);
    }
  }
}
