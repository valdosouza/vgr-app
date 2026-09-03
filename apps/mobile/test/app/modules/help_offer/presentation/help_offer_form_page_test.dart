import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_mobile/app/modules/help_offer/domain/entity/help_offer_entity.dart';
import 'package:vgr_mobile/app/modules/help_offer/domain/repository/help_offer_repository.dart';
import 'package:vgr_mobile/app/modules/help_offer/domain/usecase/submit_help_offer_usecase.dart';
import 'package:vgr_mobile/app/modules/help_offer/presentation/bloc/help_offer_bloc.dart';
import 'package:vgr_mobile/app/modules/help_offer/presentation/page/help_offer_form_page.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../../helpers/pump_localized.dart';

class MockHelpOfferRepository extends Mock implements HelpOfferRepository {}

void main() {
  late MockHelpOfferRepository repository;

  setUp(() {
    repository = MockHelpOfferRepository();
    registerFallbackValue(const HelpOfferEntity(
      reportId: 0,
      helpType: HelpType.share,
      anonymous: true,
    ));
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required bool owns,
    bool done = false,
    bool identified = false,
    VoidCallback? onDone,
  }) async {
    await pumpLocalized(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => IdentityBloc()
              ..add(identified
                  ? const ProviderLoginCompleted(
                      role: Role.helper,
                      anonymityMode: AnonymityMode.identifiedWithReward,
                      token: 'jwt',
                    )
                  : const ProviderLoginCompleted(
                      role: Role.anonymous,
                      anonymityMode: AnonymityMode.anonymous,
                    )),
          ),
          BlocProvider(
            create: (_) => HelpOfferBloc(
              SubmitHelpOfferUsecase(repository, ownsReport: (_) async => owns),
              ownsReport: (_) async => owns,
            ),
          ),
        ],
        child: HelpOfferFormPage(reportId: 5, onDone: onDone),
      ),
    );
  }

  bool submitEnabled(WidgetTester tester) =>
      tester
          .widget<VgrPrimaryButton>(find.byKey(const Key('offer-submit-button')))
          .onPressed !=
      null;

  testWidgets('own report: submit is DISABLED with a message, not just '
      'rejected (decision 20, spec scenario)', (tester) async {
    await pumpPage(tester, owns: true);

    expect(find.byKey(const Key('offer-blocked')), findsOneWidget);
    expect(submitEnabled(tester), isFalse);
    verifyNever(() => repository.submit(any()));
  });

  testWidgets('anonymous helper sees the reward-ineligibility notice and can '
      'STILL submit (decisions 34/35)', (tester) async {
    when(() => repository.submit(any())).thenAnswer((_) async => const Right(31));
    await pumpPage(tester, owns: false);

    expect(find.byKey(const Key('offer-anonymous-notice')), findsOneWidget);
    expect(submitEnabled(tester), isFalse); // nothing selected yet

    await tester.tap(find.byKey(const Key('offer-type-physical_presence')));
    await tester.pumpAndSettle();
    expect(submitEnabled(tester), isTrue);

    await tester.tap(find.byKey(const Key('offer-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('offer-success-view')), findsOneWidget);
    final sent = verify(() => repository.submit(captureAny())).captured.single
        as HelpOfferEntity;
    expect(sent.helpType, HelpType.physicalPresence);
    expect(sent.anonymous, isTrue);
  });

  testWidgets('selecting a second type unselects the first — one offer, one '
      'type (decision 10)', (tester) async {
    await pumpPage(tester, owns: false);

    await tester.tap(find.byKey(const Key('offer-type-share')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('offer-type-remote_support')));
    await tester.pumpAndSettle();

    bool checked(String wire) => tester
        .widget<VgrCheckboxTile>(find.byKey(Key('offer-type-$wire')))
        .value;
    expect(checked('share'), isFalse);
    expect(checked('remote_support'), isTrue);
  });

  testWidgets('a duplicate offer shows the translated error and keeps the '
      'form usable', (tester) async {
    when(() => repository.submit(any())).thenAnswer((_) async => const Left(
        Failure(message: 'dup', statusCode: 409, code: 'DUPLICATE')));
    await pumpPage(tester, owns: false);

    await tester.tap(find.byKey(const Key('offer-type-share')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('offer-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('offer-error')), findsOneWidget);
    expect(find.text('This value already exists.'), findsOneWidget);
    expect(submitEnabled(tester), isTrue); // selection kept for retry
  });

  testWidgets('identified helper sees the reward-onboarding link on success '
      '(decisions 104/143)', (tester) async {
    when(() => repository.submit(any())).thenAnswer((_) async => const Right(31));
    await pumpPage(tester, owns: false, identified: true);

    await tester.tap(find.byKey(const Key('offer-type-share')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('offer-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('offer-reward-onboarding-link')), findsOneWidget);
  });

  testWidgets('anonymous helper never sees the reward-onboarding link '
      '(decisions 34/35 — cannot claim a reward)', (tester) async {
    when(() => repository.submit(any())).thenAnswer((_) async => const Right(31));
    await pumpPage(tester, owns: false, identified: false);

    await tester.tap(find.byKey(const Key('offer-type-share')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('offer-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('offer-reward-onboarding-link')), findsNothing);
  });

  testWidgets('success screen calls the done seam', (tester) async {
    when(() => repository.submit(any())).thenAnswer((_) async => const Right(31));
    var popped = false;
    await pumpPage(tester, owns: false, onDone: () => popped = true);

    await tester.tap(find.byKey(const Key('offer-type-share')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('offer-submit-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('offer-done-button')));

    expect(popped, isTrue);
  });

  testWidgets('anonymous helper is told BEFORE offering that without an account there is '
      'no chat (decisions 169/34) — and can still submit', (tester) async {
    await pumpPage(tester, owns: false, identified: false);

    expect(find.byKey(const Key('offer-anonymous-no-chat-notice')), findsOneWidget);
    expect(find.textContaining('no chat'), findsOneWidget);
    await tester.tap(find.byKey(const Key('offer-type-share')));
    await tester.pumpAndSettle();
    expect(submitEnabled(tester), isTrue);
  });

  testWidgets('identified helper gets no such notice', (tester) async {
    await pumpPage(tester, owns: false, identified: true);

    expect(find.byKey(const Key('offer-anonymous-no-chat-notice')), findsNothing);
  });
}
