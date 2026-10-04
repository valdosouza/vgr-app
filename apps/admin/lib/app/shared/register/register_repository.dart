import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

/// What a module's repository offers the register factory (PS2 —
/// decisions 217/220): one paged list and the three writes. [T] is the
/// entity the list shows, [D] the draft the form produces — kept apart
/// because a form rarely carries the whole entity (a user's password goes
/// in, never comes back).
abstract interface class RegisterRepository<T, D> {
  /// One page, `filter` matched by the API on the resource's text columns.
  Future<Either<Failure, PagedResult<T>>> list(PagedQuery query);

  Future<Either<Failure, T>> create(D draft);

  Future<Either<Failure, T>> update(T current, D draft);

  Future<Either<Failure, Unit>> delete(T item);
}
