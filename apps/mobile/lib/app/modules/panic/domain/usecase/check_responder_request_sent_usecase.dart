import '../repository/panic_repository.dart';

/// Whether this device already sent a responder-authorization request
/// (decision 190) — read by the account page so the tile does not invite
/// an accidental duplicate (the API has no uniqueness constraint).
class CheckResponderRequestSentUsecase {
  const CheckResponderRequestSentUsecase(this._repository);

  final PanicRepository _repository;

  Future<bool> call() => _repository.responderRequestAlreadySent();
}
