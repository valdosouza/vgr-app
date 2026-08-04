import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class GeoPoint extends Equatable {
  const GeoPoint({required this.lat, required this.lng});

  final double lat;
  final double lng;

  @override
  List<Object?> get props => [lat, lng];
}

/// Port for the device position (decision 7 — position is mandatory on
/// submit). The geolocator plugin stays behind this contract; the plugin
/// choice was still open in the ADR and must remain swappable.
abstract class LocationGateway {
  /// Current position, requesting permission if needed. Left when the
  /// user denies permission or location services are off — the form
  /// surfaces that as a retryable state, never as a crash.
  Future<Either<Failure, GeoPoint>> currentPosition();
}
