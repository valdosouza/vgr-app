import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_mobile/app/modules/reward_onboarding/domain/entity/reward_recipient_profile_entity.dart';
import 'package:vgr_mobile/app/modules/reward_onboarding/domain/repository/reward_onboarding_repository.dart';
import 'package:vgr_mobile/app/modules/reward_onboarding/domain/usecase/get_onboarding_status_usecase.dart';
import 'package:vgr_mobile/app/modules/reward_onboarding/domain/usecase/submit_onboarding_usecase.dart';
import 'package:vgr_mobile/app/modules/reward_onboarding/presentation/bloc/reward_onboarding_bloc.dart';

class MockRewardOnboardingRepository extends Mock
    implements RewardOnboardingRepository {}

const _profile = RewardRecipientProfileEntity(
  legalName: 'Helper Name',
  email: 'helper@example.com',
  taxId: '12345678900',
  mobilePhone: '11999998888',
  monthlyIncome: 3000,
  street: 'Rua A',
  number: '10',
  neighborhood: 'Centro',
  postalCode: '01001000',
);

void main() {
  late MockRewardOnboardingRepository repository;

  setUp(() {
    repository = MockRewardOnboardingRepository();
    registerFallbackValue(_profile);
  });

  RewardOnboardingBloc build() => RewardOnboardingBloc(
        GetOnboardingStatusUsecase(repository),
        SubmitOnboardingUsecase(repository),
      );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('not yet onboarded: starts on the form', () async {
    when(() => repository.getStatus()).thenAnswer((_) async => const Right(false));

    final bloc = build()..add(const OnboardingStarted());
    await settle();

    expect(bloc.state, const OnboardingForm());
  });

  test('already onboarded: skips straight past the form (avoids a '
      'guaranteed 409)', () async {
    when(() => repository.getStatus()).thenAnswer((_) async => const Right(true));

    final bloc = build()..add(const OnboardingStarted());
    await settle();

    expect(bloc.state, const OnboardingAlreadyDone());
    verifyNever(() => repository.submit(any()));
  });

  test('status load failure surfaces as OnboardingLoadError', () async {
    const failure = Failure(message: 'down', code: 'OFFLINE');
    when(() => repository.getStatus()).thenAnswer((_) async => const Left(failure));

    final bloc = build()..add(const OnboardingStarted());
    await settle();

    expect(bloc.state, const OnboardingLoadError(failure));
  });

  test('submit succeeds: goes to OnboardingSuccess', () async {
    when(() => repository.getStatus()).thenAnswer((_) async => const Right(false));
    when(() => repository.submit(any())).thenAnswer((_) async => const Right(null));

    final bloc = build()..add(const OnboardingStarted());
    await settle();
    bloc.add(const OnboardingSubmitPressed(_profile));
    await settle();

    expect(bloc.state, const OnboardingSuccess());
    final sent = verify(() => repository.submit(captureAny())).captured.single
        as RewardRecipientProfileEntity;
    expect(sent, _profile);
  });

  test('a repeat-onboarding failure (DUPLICATE) lands on AlreadyDone, not a '
      'raw error', () async {
    when(() => repository.getStatus()).thenAnswer((_) async => const Right(false));
    when(() => repository.submit(any())).thenAnswer(
      (_) async => const Left(Failure(message: 'dup', statusCode: 409, code: 'DUPLICATE')),
    );

    final bloc = build()..add(const OnboardingStarted());
    await settle();
    bloc.add(const OnboardingSubmitPressed(_profile));
    await settle();

    expect(bloc.state, const OnboardingAlreadyDone());
  });

  test('any other submit failure keeps the form so the user can retry', () async {
    const failure = Failure(message: 'bad', statusCode: 422, code: 'VALIDATION_FAILED');
    when(() => repository.getStatus()).thenAnswer((_) async => const Right(false));
    when(() => repository.submit(any())).thenAnswer((_) async => const Left(failure));

    final bloc = build()..add(const OnboardingStarted());
    await settle();
    bloc.add(const OnboardingSubmitPressed(_profile));
    await settle();

    expect(bloc.state, const OnboardingForm(failure: failure));
  });

  test('submit before the form is ready is a no-op', () async {
    final bloc = build();
    bloc.add(const OnboardingSubmitPressed(_profile));
    await settle();

    verifyNever(() => repository.submit(any()));
  });
}
