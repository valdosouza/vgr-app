import 'package:dartz/dartz.dart';

import '../../error/failure.dart';
import 'current_user.dart';

abstract class CurrentUserRepository {
  Future<Either<Failure, CurrentUser>> getMe();
}
