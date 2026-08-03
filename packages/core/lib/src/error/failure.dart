import 'package:equatable/equatable.dart';

/// Uniform error type returned as the `Left` side of every
/// `Either<Failure, T>` across the domain layer (data/repository ->
/// domain/usecase -> presentation/bloc).
class Failure extends Equatable {
  const Failure({required this.message, this.statusCode, this.code});

  final String message;

  /// HTTP status code, when the Failure originated from an API response.
  /// Null for client-side failures (e.g. no connectivity).
  final int? statusCode;

  /// Error catalog code from the API's error envelope, when present.
  final String? code;

  @override
  List<Object?> get props => [message, statusCode, code];
}
