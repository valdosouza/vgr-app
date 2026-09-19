import 'package:equatable/equatable.dart';

/// Fixed list from decision 10 — the app offers exactly these choices,
/// mirroring the API's closed enum (never free text).
enum HelpType {
  physicalPresence('physical_presence'),
  relayInformation('relay_information'),
  remoteSupport('remote_support'),
  share('share'),
  financialContribution('financial_contribution');

  const HelpType(this.wire);

  /// The value the API speaks (and the i18n key suffix).
  final String wire;

  /// The wire value back to the enum; null for anything outside the
  /// closed list (a newer API could add a front this build does not know
  /// — it is ignored, never crashes the form).
  static HelpType? fromWire(String wire) {
    for (final type in values) {
      if (type.wire == wire) return type;
    }
    return null;
  }
}

/// A help offer as this device submitted it (spec task 09 as amended;
/// decision 208 — a SET of fronts, one to five, never empty).
class HelpOfferEntity extends Equatable {
  const HelpOfferEntity({
    required this.reportId,
    required this.helpTypes,
    required this.anonymous,
  });

  final int reportId;
  final Set<HelpType> helpTypes;

  /// Identification is the HELPER's choice (decision 6); without a
  /// session the offer is anonymous by definition (35).
  final bool anonymous;

  @override
  List<Object?> get props => [reportId, helpTypes, anonymous];
}

/// Serializes a set of fronts for the wire in decision 10's order —
/// the API accepts any order and answers alphabetically.
List<String> helpTypesToWire(Set<HelpType> types) =>
    [for (final type in HelpType.values) if (types.contains(type)) type.wire];
