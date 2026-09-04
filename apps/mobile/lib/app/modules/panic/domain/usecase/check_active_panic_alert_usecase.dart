import '../repository/panic_repository.dart';

/// Surfaces the locally-remembered active alert (no PP1 endpoint exists to
/// read it from the server, see `panic_repository.dart`'s doc comment) —
/// dispatched once by `PanicHubPage`'s `initState`, same idiom as every
/// other Started event in this app.
class CheckActivePanicAlertUsecase {
  const CheckActivePanicAlertUsecase(this._repository);

  final PanicRepository _repository;

  Future<int?> call() => _repository.currentActiveAlertId();
}
