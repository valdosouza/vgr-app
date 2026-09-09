import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/gateway/location_gateway.dart';

/// geolocator-backed adapter (plugin stays behind the port — the ADR left
/// the location plugin choice open). Codes map to `core.errors.<code>`.
class GeolocatorLocationGateway implements LocationGateway {
  const GeolocatorLocationGateway();

  /// Upper bound for a fix. Without it the web target can wait forever:
  /// Chrome never answers when the OS location service is off or the
  /// network provider fails, and the feed would spin indefinitely instead
  /// of surfacing the retryable `LOCATION_ERROR`.
  static const _fixTimeout = Duration(seconds: 15);

  @override
  Future<Either<Failure, GeoPoint>> currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const Left(Failure(message: 'Location services are off', code: 'LOCATION_OFF'));
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const Left(
          Failure(message: 'Location permission denied', code: 'LOCATION_DENIED'),
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(timeLimit: _fixTimeout),
      ).timeout(_fixTimeout);
      return Right(GeoPoint(lat: position.latitude, lng: position.longitude));
    } catch (_) {
      return const Left(Failure(message: 'Could not read location', code: 'LOCATION_ERROR'));
    }
  }
}
