import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_mobile/app/modules/auth/domain/repository/auth_repository.dart';
import 'package:vgr_mobile/app/modules/auth/domain/usecase/confirm_email_verification_usecase.dart';
import 'package:vgr_mobile/app/modules/auth/domain/usecase/send_email_verification_usecase.dart';
import 'package:vgr_mobile/app/modules/auth/presentation/bloc/email_verification_bloc.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
  });

  EmailVerificationBloc build() => EmailVerificationBloc(
        SendEmailVerificationUsecase(repository),
        ConfirmEmailVerificationUsecase(repository),
      );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('send moves to the code step', () async {
    when(() => repository.sendEmailVerification()).thenAnswer((_) async => const Right(null));

    final bloc = build()..add(const EmailVerificationSendPressed());
    await settle();

    expect(bloc.state, const EmailVerificationCodeSent());
  });

  test('a send failure stays on the send step with the error', () async {
    const failure = Failure(message: 'down', code: 'OFFLINE');
    when(() => repository.sendEmailVerification()).thenAnswer((_) async => const Left(failure));

    final bloc = build()..add(const EmailVerificationSendPressed());
    await settle();

    expect(bloc.state, const EmailVerificationSendFailed(failure));
  });

  test('confirm with the right code succeeds', () async {
    when(() => repository.sendEmailVerification()).thenAnswer((_) async => const Right(null));
    when(() => repository.confirmEmailVerification(any()))
        .thenAnswer((_) async => const Right(null));

    final bloc = build()..add(const EmailVerificationSendPressed());
    await settle();
    bloc.add(const EmailVerificationConfirmPressed('123456'));
    await settle();

    expect(bloc.state, const EmailVerificationSuccess());
    verify(() => repository.confirmEmailVerification('123456')).called(1);
  });

  test('a wrong code stays on the code step carrying the failure', () async {
    const failure = Failure(message: 'Invalid or expired code', statusCode: 401, code: 'UNAUTHORIZED');
    when(() => repository.sendEmailVerification()).thenAnswer((_) async => const Right(null));
    when(() => repository.confirmEmailVerification(any()))
        .thenAnswer((_) async => const Left(failure));

    final bloc = build()..add(const EmailVerificationSendPressed());
    await settle();
    bloc.add(const EmailVerificationConfirmPressed('000000'));
    await settle();

    expect(bloc.state, const EmailVerificationCodeSent(failure: failure));
  });

  test('confirm before a code was ever sent is a no-op', () async {
    build().add(const EmailVerificationConfirmPressed('123456'));
    await settle();

    verifyNever(() => repository.confirmEmailVerification(any()));
  });
}
