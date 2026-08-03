/// Admin-managed risk classification per Category (decision 46), shared
/// by every module that must branch on it: mandatory anonymity (decision
/// 40), hidden engagement (decision 41), payment mode (decision 58), and
/// the helper-facing severity filter (decision 49).
enum RiskTier { low, medium, high }

extension RiskTierJson on RiskTier {
  static RiskTier fromJson(String value) => RiskTier.values.byName(value);
  String toJson() => name;
}
