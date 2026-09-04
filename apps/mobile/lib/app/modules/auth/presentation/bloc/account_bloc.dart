import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

sealed class AccountState extends Equatable {
  const AccountState();

  @override
  List<Object?> get props => [];
}

class AccountReady extends AccountState {
  const AccountReady({this.reputation, this.reputationLoading = false});

  /// The signed-in helper's OWN aggregate (184) — never anyone else's
  /// (185); null until `AccountStarted` resolves, or forever on a failed
  /// read (this section is entirely optional, decision 123).
  final ReputationEntity? reputation;
  final bool reputationLoading;

  AccountReady copyWith({ReputationEntity? reputation, bool? reputationLoading}) => AccountReady(
        reputation: reputation ?? this.reputation,
        reputationLoading: reputationLoading ?? this.reputationLoading,
      );

  @override
  List<Object?> get props => [reputation, reputationLoading];
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
  ) : super(const AccountReady()) {
    on<AccountStarted>(_onStarted);
    on<AccountSignOutPressed>(_onSignOutPressed);
  }

  final SignOutUsecase _signOut;
  final IdentityBloc _identityBloc;
  final LocalPrefs _localPrefs;
  final GetMyReputationUsecase _getMyReputation;

  Future<void> _onStarted(AccountStarted event, Emitter<AccountState> emit) async {
    final current = state;
    if (current is! AccountReady) return;
    emit(current.copyWith(reputationLoading: true));
    final result = await _getMyReputation();
    if (emit.isDone) return;
    final latest = state;
    if (latest is! AccountReady) return;
    result.fold(
      // Best-effort (123, an entirely optional section): a failed read
      // just shows nothing, never blocks the rest of the page.
      (_) => emit(latest.copyWith(reputationLoading: false)),
      (reputation) => emit(latest.copyWith(reputation: reputation, reputationLoading: false)),
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
