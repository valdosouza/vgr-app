import 'package:equatable/equatable.dart';

/// One field's error from the API envelope (decision 83: `code` is the
/// translation key, `params` its interpolated values, `message` the English
/// fallback).
class FieldFailure extends Equatable {
  const FieldFailure({required this.field, required this.message, this.code, this.params});

  final String field;
  final String message;
  final String? code;
  final Map<String, String>? params;

  factory FieldFailure.fromJson(Map<String, dynamic> json) => FieldFailure(
        field: json['field'] as String,
        message: json['message'] as String,
        code: json['code'] as String?,
        params: (json['params'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, '$v')),
      );

  @override
  List<Object?> get props => [field, message, code, params];
}

/// Uniform error type returned as the `Left` side of every
/// `Either<Failure, T>` across the domain layer (data/repository ->
/// domain/usecase -> presentation/bloc).
class Failure extends Equatable {
  const Failure({required this.message, this.statusCode, this.code, this.fields, this.params});

  final String message;

  /// HTTP status code, when the Failure originated from an API response.
  /// Null for client-side failures (e.g. no connectivity).
  final int? statusCode;

  /// Error catalog code — since decision 80 this is the TRANSLATION
  /// CONTRACT: the API message stays English, the client translates by code
  /// (`core.errors.<code>`, message as fallback).
  final String? code;

  /// Per-field errors (validation), each with its own code (decision 83).
  final List<FieldFailure>? fields;

  /// Interpolated values referenced by the message (decision 83).
  final Map<String, String>? params;

  @override
  List<Object?> get props => [message, statusCode, code, fields, params];
}
