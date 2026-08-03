import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/identity_state.dart';
import 'identity_event.dart';

/// Holds the current Role/AnonymityMode, shared across every feature
/// module (mobile and admin). Defaults to Anonymous until a
/// registration/session action changes it.
class IdentityBloc extends Bloc<IdentityEvent, IdentityState> {
  IdentityBloc() : super(const IdentityState()) {
    on<ProviderLoginCompleted>((event, emit) {
      emit(IdentityState(role: event.role, anonymityMode: event.anonymityMode, token: event.token));
    });
  }
}
