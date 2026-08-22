import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:core/core.dart';
import 'package:vgr_mobile/app/modules/auth/domain/repository/auth_repository.dart';
import 'package:vgr_mobile/app/modules/auth/domain/usecase/confirm_email_verification_usecase.dart';
import 'package:vgr_mobile/app/modules/auth/domain/usecase/send_email_verification_usecase.dart';
import 'package:vgr_mobile/app/modules/auth/presentation/bloc/email_verification_bloc.dart';
import 'package:vgr_mobile/app/modules/auth/presentation/page/email_verification_page.dart';

import '../../../../helpers/pump_localized.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
  });

  Future<void> pumpPage(WidgetTester tester, {VoidCallback? onDone}) async {
    await pumpLocalized(
      tester,
      BlocProvider(
        create: (_) => EmailVerificationBloc(
          SendEmailVerificationUsecase(repository),
          ConfirmEmailVerificationUsecase(repository),
        ),
        child: EmailVerificationPage(onDone: onDone),
      ),
    );
  }

  testWidgets('send then confirm with the right code reaches success',
      (tester) async {
    when(() => repository.sendEmailVerification()).thenAnswer((_) async => const Right(null));
    when(() => repository.confirmEmailVerification(any()))
        .thenAnswer((_) async => const Right(null));
    var done = false;
    await pumpPage(tester, onDone: () => done = true);

    await tester.tap(find.byKey(const Key('verify-email-send-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('verify-email-code-field')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('verify-email-code-field')), '123456');
    await tester.tap(find.byKey(const Key('verify-email-confirm-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('verify-email-success-view')), findsOneWidget);

    await tester.tap(find.byKey(const Key('verify-email-done-button')));
    expect(done, isTrue);
  });

  testWidgets('a wrong code shows the raw API message, not the generic '
      '"session expired" translation of UNAUTHORIZED', (tester) async {
    when(() => repository.sendEmailVerification()).thenAnswer((_) async => const Right(null));
    when(() => repository.confirmEmailVerification(any())).thenAnswer((_) async => const Left(
        Failure(message: 'Invalid or expired code', statusCode: 401, code: 'UNAUTHORIZED')));
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('verify-email-send-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('verify-email-code-field')), '000000');
    await tester.tap(find.byKey(const Key('verify-email-confirm-button')));
    await tester.pumpAndSettle();

    expect(find.text('Invalid or expired code'), findsOneWidget);
  });

  testWidgets('a send failure shows an error and stays on the send step',
      (tester) async {
    when(() => repository.sendEmailVerification())
        .thenAnswer((_) async => const Left(Failure(message: 'down', code: 'OFFLINE')));
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('verify-email-send-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('verify-email-send-error')), findsOneWidget);
    expect(find.byKey(const Key('verify-email-code-field')), findsNothing);
  });
}
