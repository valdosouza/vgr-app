import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

abstract class AuthRepository {
  /// Returns the JWT on success. `ApiClient.setToken` is called internally
  /// as a side effect — every other repository's calls need no change.
  Future<Either<Failure, String>> login(String email, String password);
}
