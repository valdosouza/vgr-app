import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/fee_rule_entity.dart';

abstract class FeeRuleRepository {
  Future<Either<Failure, List<FeeRuleEntity>>> list();
  Future<Either<Failure, Unit>> upsert(String? category, double feePercent, Set<PaymentMode> paymentModeAllowed);
}
