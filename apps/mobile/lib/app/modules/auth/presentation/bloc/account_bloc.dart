import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecase/sign_out_usecase.dart';

sealed class AccountEvent extends Equatable {
  const AccountEvent();

  @override
  List<Object?> get props => [];
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
  const AccountReady();
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
  AccountBloc(this._signOut, this._identityBloc, this._localPrefs) : super(const AccountReady()) {
    on<AccountSignOutPressed>(_onSignOutPressed);
  }

  final SignOutUsecase _signOut;
  final IdentityBloc _identityBloc;
  final LocalPrefs _localPrefs;

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
