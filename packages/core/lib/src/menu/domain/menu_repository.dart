import 'package:dartz/dartz.dart';

import '../../error/failure.dart';
import 'menu_entity.dart';

abstract class MenuRepository {
  /// The menu tree for the session user, already filtered by VIEW grants.
  Future<Either<Failure, List<MenuModule>>> getMenus();

  /// Every grant keyed by interface — including kind 'R' resources that
  /// never appear on the menu (decision 93). Feeds SessionAccess.
  Future<Either<Failure, Map<String, List<String>>>> getPermissions();
}
