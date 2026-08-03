import 'package:flutter_test/flutter_test.dart';
import 'package:core/src/identity/domain/anonymity_mode.dart';
import 'package:core/src/identity/domain/identity_state.dart';
import 'package:core/src/identity/domain/role.dart';
import 'package:core/src/identity/presentation/identity_bloc.dart';
import 'package:core/src/identity/presentation/identity_event.dart';

void main() {
  group('IdentityBloc', () {
    test('defaults to Anonymous on app start before any login action occurs', () {
      final bloc = IdentityBloc();
      expect(
        bloc.state,
        const IdentityState(role: Role.anonymous, anonymityMode: AnonymityMode.anonymous),
      );
      bloc.close();
    });

    test('emits an updated IdentityState reflecting Role and AnonymityMode after ProviderLoginCompleted', () {
      final bloc = IdentityBloc();
      addTearDown(bloc.close);

      expectLater(
        bloc.stream,
        emitsInOrder([
          const IdentityState(
            role: Role.reporter,
            anonymityMode: AnonymityMode.identifiedNoReward,
          ),
        ]),
      );

      bloc.add(const ProviderLoginCompleted(
        role: Role.reporter,
        anonymityMode: AnonymityMode.identifiedNoReward,
      ));
    });

    test('carries the JWT through to IdentityState when ProviderLoginCompleted includes one', () {
      final bloc = IdentityBloc();
      addTearDown(bloc.close);

      expectLater(
        bloc.stream,
        emitsInOrder([
          const IdentityState(
            role: Role.admin,
            anonymityMode: AnonymityMode.anonymous,
            token: 'fake.jwt.token',
          ),
        ]),
      );

      bloc.add(const ProviderLoginCompleted(
        role: Role.admin,
        anonymityMode: AnonymityMode.anonymous,
        token: 'fake.jwt.token',
      ));
    });
  });
}
