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
}

/// A help offer as this device submitted it (spec task 09 as amended).
class HelpOfferEntity extends Equatable {
  const HelpOfferEntity({
    required this.reportId,
    required this.helpType,
    required this.anonymous,
  });

  final int reportId;
  final HelpType helpType;

  /// Identification is the HELPER's choice (decision 6); without a
  /// session the offer is anonymous by definition (35).
  final bool anonymous;

  @override
  List<Object?> get props => [reportId, helpType, anonymous];
}
