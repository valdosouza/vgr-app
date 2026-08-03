import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../domain/entity/risk_tier_config_entity.dart';
import '../domain/repository/risk_config_repository.dart';

class RiskConfigRepositoryImpl implements RiskConfigRepository {
  RiskConfigRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Either<Failure, List<RiskTierConfigEntity>>> list() async {
    try {
      final json = await _apiClient.get('/api/risk-config');
      final rows = json['data'] as List<dynamic>;
      return Right(rows
          .map((row) => RiskTierConfigEntity(
                category: row['category'] as String,
                tier: RiskTierJson.fromJson(row['tier'] as String),
              ))
          .toList());
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, Unit>> upsert(String category, RiskTier tier) async {
    try {
      await _apiClient.put('/api/risk-config/$category', {'tier': tier.toJson()});
      return const Right(unit);
    } on Failure catch (f) {
      return Left(f);
    }
  }
}
