import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../domain/entity/fee_rule_entity.dart';
import '../domain/repository/fee_rule_repository.dart';

class FeeRuleRepositoryImpl implements FeeRuleRepository {
  FeeRuleRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Either<Failure, List<FeeRuleEntity>>> list() async {
    try {
      final json = await _apiClient.get('/api/monetization-config');
      final rows = json['data'] as List<dynamic>;
      return Right(rows
          .map((row) => FeeRuleEntity(
                category: row['category'] as String?,
                feePercent: (row['feePercent'] as num).toDouble(),
                paymentModeAllowed: (row['paymentModeAllowed'] as List<dynamic>)
                    .map((mode) => PaymentModeJson.fromJson(mode as String))
                    .toSet(),
              ))
          .toList());
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, Unit>> upsert(
    String? category,
    double feePercent,
    Set<PaymentMode> paymentModeAllowed,
  ) async {
    try {
      await _apiClient.put('/api/monetization-config/${category ?? 'global'}', {
        'feePercent': feePercent,
        'paymentModeAllowed': paymentModeAllowed.map((mode) => mode.toJson()).toList(),
      });
      return const Right(unit);
    } on Failure catch (f) {
      return Left(f);
    }
  }
}
