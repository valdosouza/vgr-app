import 'package:equatable/equatable.dart';

/// The app plane's session (decision 122): a 30-minute access token plus an
/// opaque, rotating refresh token — never confused with the panel's single
/// JWT (decision 119).
class AppSessionEntity extends Equatable {
  const AppSessionEntity({
    required this.accessToken,
    required this.refreshToken,
    required this.accountId,
  });

  final String accessToken;
  final String refreshToken;
  final int accountId;

  @override
  List<Object?> get props => [accessToken, refreshToken, accountId];
}
