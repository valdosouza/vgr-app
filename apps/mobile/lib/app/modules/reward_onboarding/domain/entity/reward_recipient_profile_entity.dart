import 'package:equatable/equatable.dart';

/// KYC data the helper hands to the rail to open a payout subconta
/// (`POST /app-reward/onboarding`, decisions 143/104). Mirrors the API's
/// `onboardRecipientDto` field-for-field; the VGR never persists any of
/// this — only the opaque `railRecipientId` survives server-side.
class RewardRecipientProfileEntity extends Equatable {
  const RewardRecipientProfileEntity({
    required this.legalName,
    required this.email,
    required this.taxId,
    required this.mobilePhone,
    required this.monthlyIncome,
    required this.street,
    required this.number,
    required this.neighborhood,
    required this.postalCode,
  });

  final String legalName;
  final String email;
  final String taxId;
  final String mobilePhone;
  final num monthlyIncome;
  final String street;
  final String number;
  final String neighborhood;
  final String postalCode;

  @override
  List<Object?> get props => [
        legalName,
        email,
        taxId,
        mobilePhone,
        monthlyIncome,
        street,
        number,
        neighborhood,
        postalCode,
      ];
}
