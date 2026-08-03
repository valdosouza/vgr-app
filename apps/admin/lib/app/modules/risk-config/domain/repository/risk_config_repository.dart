import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/risk_tier_config_entity.dart';

abstract class RiskConfigRepository {
  Future<Either<Failure, List<RiskTierConfigEntity>>> list();
  Future<Either<Failure, Unit>> upsert(String category, RiskTier tier);
}
