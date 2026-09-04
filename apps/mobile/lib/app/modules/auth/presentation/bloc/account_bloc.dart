import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../panic/domain/usecase/check_responder_request_sent_usecase.dart';
import '../../../panic/domain/usecase/request_responder_authorization_usecase.dart';
import '../../../rating/domain/entity/rating_entities.dart';
import '../../../rating/domain/usecase/get_my_reputation_usecase.dart';
import '../../domain/usecase/sign_out_usecase.dart';

sealed class AccountEvent extends Equatable {
  const AccountEvent();

  @override
  List<Object?> get props => [];
}

/// Reads "my reputation" (RT2, decisions 184/185) — dispatched once by the
/// page's `initState`, same idiom as every other Started event in this app.
class AccountStarted extends AccountEvent {
  const AccountStarted();
}

class AccountSignOutPressed extends AccountEvent {
  const AccountSignOutPressed();
}

/// The now-reachable responder-authorization request (decision 190, PP2)
/// — dispatched ONLY after the page's own `showVgrConfirm`, same idiom as
/// `PanicTriggerPressed`; this bloc never re-derives that confirmation.
class AccountResponderRequestPressed extends AccountEvent {
  const AccountResponderRequestPressed();
}

sealed class AccountState extends Equatable {
  const AccountState();

  @override
  List<Object?> get props => [];
}

class AccountReady extends AccountState {
  const AccountReady({
    this.reputation,
    this.reputationLoading = false,
    this.responderRequestSent = false,
    this.responderRequestSending = false,
    this.responderRequestFailure,
  });

  /// The signed-in helper's OWN aggregate (184) — never anyone else's
  /// (185); null until `AccountStarted` resolves, or forever on a failed
  /// read (this section is entirely optional, decision 123).
  final ReputationEntity? reputation;
  final bool reputationLoading;

  /// Whether THIS DEVICE already sent a responder-authorization request
  /// (decision 190) — purely local bookkeeping (no PP1 endpoint reads
  /// membership status back, see `panic_repository.dart`), so the tile
  /// never re-invites a tap once this is true.
  final bool responderRequestSent;
  final bool responderRequestSending;
  final Failure? responderRequestFailure;

  AccountReady copyWith({
    ReputationEntity? reputation,
    bool? reputationLoading,
    bool? responderRequestSent,
    bool? responderRequestSending,
    Failure? responderRequestFailure,
    bool clearResponderRequestFailure = false,
  }) =>
      AccountReady(
        reputation: reputation ?? this.reputation,
        reputationLoading: reputationLoading ?? this.reputationLoading,
        responderRequestSent: responderRequestSent ?? this.responderRequestSent,
        responderRequestSending: responderRequestSending ?? this.responderRequestSending,
        responderRequestFailure: clearResponderRequestFailure
            ? null
            : (responderRequestFailure ?? this.responderRequestFailure),
      );

  @override
  List<Object?> get props => [
        reputation,
        reputationLoading,
        responderRequestSent,
        responderRequestSending,
        responderRequestFailure,
      ];
}

class AccountSigningOut extends AccountState {
  const AccountSigningOut();
}

class AccountSignedOut extends AccountState {
  const AccountSignedOut();
}

/// Signing out of the identified account (decision 122's only shape:
/// revoke every session). Best-effort against the API — a dead token or a
/// transport failure never blocks the LOCAL sign-out, or the account
/// would be stuck "logged in" on a session that already cannot be used.
class AccountBloc extends Bloc<AccountEvent, AccountState> {
  AccountBloc(
    this._signOut,
    this._identityBloc,
    this._localPrefs,
    this._getMyReputation,
    this._checkResponderRequestSent,
    this._requestResponderAuthorization,
  ) : super(const AccountReady()) {
    on<AccountStarted>(_onStarted);
    on<AccountSignOutPressed>(_onSignOutPressed);
    on<AccountResponderRequestPressed>(_onResponderRequestPressed);
  }

  final SignOutUsecase _signOut;
  final IdentityBloc _identityBloc;
  final LocalPrefs _localPrefs;
  final GetMyReputationUsecase _getMyReputation;
  final CheckResponderRequestSentUsecase _checkResponderRequestSent;
  final RequestResponderAuthorizationUsecase _requestResponderAuthorization;

  Future<void> _onStarted(AccountStarted event, Emitter<AccountState> emit) async {
    final current = state;
    if (current is! AccountReady) return;
    emit(current.copyWith(reputationLoading: true));
    final result = await _getMyReputation();
    final alreadySent = await _checkResponderRequestSent();
    if (emit.isDone) return;
    final latest = state;
    if (latest is! AccountReady) return;
    result.fold(
      // Best-effort (123, an entirely optional section): a failed read
      // just shows nothing, never blocks the rest of the page.
      (_) => emit(latest.copyWith(
        reputationLoading: false,
        responderRequestSent: alreadySent,
      )),
      (reputation) => emit(latest.copyWith(
        reputation: reputation,
        reputationLoading: false,
        responderRequestSent: alreadySent,
      )),
    );
  }

  /// The page already confirmed via `showVgrConfirm` before dispatching
  /// this (decision 65's same posture applied to the responder request).
  Future<void> _onResponderRequestPressed(
    AccountResponderRequestPressed event,
    Emitter<AccountState> emit,
  ) async {
    final current = state;
    if (current is! AccountReady) return;
    // Never invites a duplicate — the API has no uniqueness constraint
    // against a repeat POST (see `panic.md`'s "Plane fix" section), so
    // this local guard is the only thing stopping one.
    if (current.responderRequestSent || current.responderRequestSending) return;

    emit(current.copyWith(
      responderRequestSending: true,
      clearResponderRequestFailure: true,
    ));
    final result = await _requestResponderAuthorization();
    if (emit.isDone) return;
    final latest = state;
    if (latest is! AccountReady) return;
    result.fold(
      (failure) => emit(latest.copyWith(
        responderRequestSending: false,
        responderRequestFailure: failure,
      )),
      (_) => emit(latest.copyWith(
        responderRequestSending: false,
        responderRequestSent: true,
      )),
    );
  }

  Future<void> _onSignOutPressed(
    AccountSignOutPressed event,
    Emitter<AccountState> emit,
  ) async {
    emit(const AccountSigningOut());
    await _signOut();
    if (emit.isDone) return;
    await _localPrefs.clearAppSession();
    _identityBloc.add(const ProviderLoginCompleted(
      role: Role.anonymous,
      anonymityMode: AnonymityMode.anonymous,
    ));
    emit(const AccountSignedOut());
  }
}
