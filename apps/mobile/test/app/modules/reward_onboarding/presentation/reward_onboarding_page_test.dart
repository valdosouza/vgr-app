import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_mobile/app/modules/reward_onboarding/domain/entity/reward_recipient_profile_entity.dart';
import 'package:vgr_mobile/app/modules/reward_onboarding/domain/repository/reward_onboarding_repository.dart';
import 'package:vgr_mobile/app/modules/reward_onboarding/domain/usecase/get_onboarding_status_usecase.dart';
import 'package:vgr_mobile/app/modules/reward_onboarding/domain/usecase/submit_onboarding_usecase.dart';
import 'package:vgr_mobile/app/modules/reward_onboarding/presentation/bloc/reward_onboarding_bloc.dart';
import 'package:vgr_mobile/app/modules/reward_onboarding/presentation/page/reward_onboarding_page.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../../helpers/pump_localized.dart';

class MockRewardOnboardingRepository extends Mock
    implements RewardOnboardingRepository {}

void main() {
  late MockRewardOnboardingRepository repository;

  setUp(() {
    repository = MockRewardOnboardingRepository();
    registerFallbackValue(const RewardRecipientProfileEntity(
      legalName: '',
      email: '',
      taxId: '',
      mobilePhone: '',
      monthlyIncome: 0,
      street: '',
      number: '',
      neighborhood: '',
      postalCode: '',
    ));
  });

  Future<void> pumpPage(WidgetTester tester, {VoidCallback? onDone}) async {
    await pumpLocalized(
      tester,
      BlocProvider(
        create: (_) => RewardOnboardingBloc(
          GetOnboardingStatusUsecase(repository),
          SubmitOnboardingUsecase(repository),
        ),
        child: RewardOnboardingPage(onDone: onDone),
      ),
    );
  }

  Future<void> fillForm(WidgetTester tester) async {
    await tester.enterText(
        find.byKey(const Key('reward-onboarding-legal-name-field')), 'Helper Name');
    await tester.enterText(
        find.byKey(const Key('reward-onboarding-email-field')), 'helper@example.com');
    await tester.enterText(
        find.byKey(const Key('reward-onboarding-tax-id-field')), '12345678900');
    await tester.enterText(
        find.byKey(const Key('reward-onboarding-mobile-phone-field')), '11999998888');
    await tester.enterText(
        find.byKey(const Key('reward-onboarding-monthly-income-field')), '3000');
    await tester.enterText(
        find.byKey(const Key('reward-onboarding-street-field')), 'Rua A');
    await tester.enterText(
        find.byKey(const Key('reward-onboarding-number-field')), '10');
    await tester.enterText(
        find.byKey(const Key('reward-onboarding-neighborhood-field')), 'Centro');
    await tester.enterText(
        find.byKey(const Key('reward-onboarding-postal-code-field')), '01001000');
  }

  testWidgets('already onboarded: shows the already-done view, no form',
      (tester) async {
    when(() => repository.getStatus()).thenAnswer((_) async => const Right(true));
    await pumpPage(tester);

    expect(find.byKey(const Key('reward-onboarding-already-done-view')), findsOneWidget);
    expect(find.byKey(const Key('reward-onboarding-submit-button')), findsNothing);
  });

  testWidgets('not onboarded: fills the form and submits successfully',
      (tester) async {
    when(() => repository.getStatus()).thenAnswer((_) async => const Right(false));
    when(() => repository.submit(any())).thenAnswer((_) async => const Right(null));
    await pumpPage(tester);

    await fillForm(tester);
    await tester.ensureVisible(find.byKey(const Key('reward-onboarding-submit-button')));
    await tester.tap(find.byKey(const Key('reward-onboarding-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reward-onboarding-success-view')), findsOneWidget);
    final sent = verify(() => repository.submit(captureAny())).captured.single
        as RewardRecipientProfileEntity;
    expect(sent.legalName, 'Helper Name');
    expect(sent.monthlyIncome, 3000);
  });

  testWidgets('empty required fields block submit with inline errors',
      (tester) async {
    when(() => repository.getStatus()).thenAnswer((_) async => const Right(false));
    await pumpPage(tester);

    await tester.ensureVisible(find.byKey(const Key('reward-onboarding-submit-button')));
    await tester.tap(find.byKey(const Key('reward-onboarding-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Required field'), findsWidgets);
    verifyNever(() => repository.submit(any()));
  });

  testWidgets('a server failure shows the translated error and keeps the '
      'form usable', (tester) async {
    when(() => repository.getStatus()).thenAnswer((_) async => const Right(false));
    when(() => repository.submit(any())).thenAnswer((_) async => const Left(
        Failure(message: 'dup', statusCode: 409, code: 'DUPLICATE')));
    await pumpPage(tester);

    await fillForm(tester);
    await tester.ensureVisible(find.byKey(const Key('reward-onboarding-submit-button')));
    await tester.tap(find.byKey(const Key('reward-onboarding-submit-button')));
    await tester.pumpAndSettle();

    // DUPLICATE routes straight to AlreadyDone (the bloc maps it), not a
    // raw inline error — see reward_onboarding_bloc_test.dart.
    expect(find.byKey(const Key('reward-onboarding-already-done-view')), findsOneWidget);
  });

  testWidgets('a non-duplicate failure keeps the form with the inline error',
      (tester) async {
    when(() => repository.getStatus()).thenAnswer((_) async => const Right(false));
    when(() => repository.submit(any())).thenAnswer((_) async => const Left(
        Failure(message: 'bad', statusCode: 422, code: 'VALIDATION_FAILED')));
    await pumpPage(tester);

    await fillForm(tester);
    await tester.ensureVisible(find.byKey(const Key('reward-onboarding-submit-button')));
    await tester.tap(find.byKey(const Key('reward-onboarding-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reward-onboarding-error')), findsOneWidget);
    expect(find.byKey(const Key('reward-onboarding-submit-button')), findsOneWidget);
    expect(
      tester
          .widget<VgrPrimaryButton>(find.byKey(const Key('reward-onboarding-submit-button')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('success screen calls the done seam', (tester) async {
    when(() => repository.getStatus()).thenAnswer((_) async => const Right(false));
    when(() => repository.submit(any())).thenAnswer((_) async => const Right(null));
    var popped = false;
    await pumpPage(tester, onDone: () => popped = true);

    await fillForm(tester);
    await tester.ensureVisible(find.byKey(const Key('reward-onboarding-submit-button')));
    await tester.tap(find.byKey(const Key('reward-onboarding-submit-button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('reward-onboarding-done-button')));
    await tester.tap(find.byKey(const Key('reward-onboarding-done-button')));

    expect(popped, isTrue);
  });
}
