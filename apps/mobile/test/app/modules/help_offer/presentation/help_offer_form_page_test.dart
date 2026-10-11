import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_mobile/app/modules/help_offer/domain/entity/help_offer_entity.dart';
import 'package:vgr_mobile/app/modules/help_offer/domain/repository/help_offer_repository.dart';
import 'package:vgr_mobile/app/modules/help_offer/domain/usecase/submit_help_offer_usecase.dart';
import 'package:vgr_mobile/app/modules/help_offer/domain/usecase/update_help_offer_types_usecase.dart';
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
      helpTypes: {HelpType.share},
      anonymous: true,
    ));
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required bool owns,
    bool done = false,
    bool identified = false,
    String? tier = 'low',
    VoidCallback? onDone,
    HelpOfferEdit? editing,
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
              UpdateHelpOfferTypesUsecase(repository),
              ownsReport: (_) async => owns,
            ),
          ),
        ],
        child: HelpOfferFormPage(
          reportId: 5,
          tier: tier,
          onDone: onDone,
          editing: editing,
        ),
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

    await tester.ensureVisible(find.byKey(const Key('offer-submit-button')));
    await tester.tap(find.byKey(const Key('offer-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('offer-success-view')), findsOneWidget);
    final sent = verify(() => repository.submit(captureAny())).captured.single
        as HelpOfferEntity;
    expect(sent.helpTypes, {HelpType.physicalPresence});
    expect(sent.anonymous, isTrue);
  });

  bool checked(WidgetTester tester, String wire) =>
      tester.widget<VgrCheckboxTile>(find.byKey(Key('offer-type-$wire'))).value;

  testWidgets('checking a second type KEEPS the first — several fronts per offer '
      '(decision 208; success criterion 5)', (tester) async {
    when(() => repository.submit(any())).thenAnswer((_) async => const Right(31));
    await pumpPage(tester, owns: false);

    await tester.tap(find.byKey(const Key('offer-type-share')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('offer-type-remote_support')));
    await tester.pumpAndSettle();

    expect(checked(tester, 'share'), isTrue);
    expect(checked(tester, 'remote_support'), isTrue);
    expect(checked(tester, 'physical_presence'), isFalse);

    await tester.ensureVisible(find.byKey(const Key('offer-submit-button')));
    await tester.tap(find.byKey(const Key('offer-submit-button')));
    await tester.pumpAndSettle();

    final sent = verify(() => repository.submit(captureAny())).captured.single
        as HelpOfferEntity;
    expect(sent.helpTypes, {HelpType.share, HelpType.remoteSupport});
  });

  testWidgets('unchecking the only type disables submit again (208: minimum one)',
      (tester) async {
    await pumpPage(tester, owns: false);

    await tester.tap(find.byKey(const Key('offer-type-share')));
    await tester.pumpAndSettle();
    expect(submitEnabled(tester), isTrue);

    await tester.tap(find.byKey(const Key('offer-type-share')));
    await tester.pumpAndSettle();
    expect(checked(tester, 'share'), isFalse);
    expect(submitEnabled(tester), isFalse);
  });

  testWidgets('a duplicate offer shows the translated error and keeps the '
      'form usable', (tester) async {
    when(() => repository.submit(any())).thenAnswer((_) async => const Left(
        Failure(message: 'dup', statusCode: 409, code: 'DUPLICATE')));
    await pumpPage(tester, owns: false);

    await tester.tap(find.byKey(const Key('offer-type-share')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('offer-submit-button')));
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
    await tester.ensureVisible(find.byKey(const Key('offer-submit-button')));
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
    await tester.ensureVisible(find.byKey(const Key('offer-submit-button')));
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
    await tester.ensureVisible(find.byKey(const Key('offer-submit-button')));
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

  testWidgets('anonymous helper is ALSO told they cannot be rated without an account '
      '(decision 180, extends 169) — and can still submit', (tester) async {
    await pumpPage(tester, owns: false, identified: false);

    expect(find.byKey(const Key('offer-anonymous-no-rating-notice')), findsOneWidget);
    expect(find.textContaining('rated'), findsOneWidget);
    await tester.tap(find.byKey(const Key('offer-type-share')));
    await tester.pumpAndSettle();
    expect(submitEnabled(tester), isTrue);
  });

  testWidgets('identified helper gets no rating notice either', (tester) async {
    await pumpPage(tester, owns: false, identified: true);

    expect(find.byKey(const Key('offer-anonymous-no-rating-notice')), findsNothing);
  });

  group('showing the helper\'s name passes the risk analysis (decisions 237/238)', () {
    Future<HelpOfferEntity> submitShare(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('offer-type-share')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('offer-submit-button')));
      await tester.tap(find.byKey(const Key('offer-submit-button')));
      await tester.pumpAndSettle();
      return verify(() => repository.submit(captureAny())).captured.single
          as HelpOfferEntity;
    }

    bool showNameChecked(WidgetTester tester) => tester
        .widget<VgrCheckboxTile>(find.byKey(const Key('offer-show-name')))
        .value;

    testWidgets('a helper with an account is HIDDEN unless they check it — the '
        'box starts unchecked, with the fake-report warning (237)', (tester) async {
      when(() => repository.submit(any())).thenAnswer((_) async => const Right(31));
      await pumpPage(tester, owns: false, identified: true, tier: 'low');

      expect(find.text('Show my name to the reporter'), findsOneWidget);
      expect(showNameChecked(tester), isFalse);
      expect(find.byKey(const Key('offer-show-name-warning')), findsOneWidget);
      expect(find.textContaining('a report can be fake'), findsOneWidget);

      final sent = await submitShare(tester);
      expect(sent.anonymous, isTrue);
      // Hidden is social only: the account still claims a reward (60).
      expect(find.byKey(const Key('offer-reward-onboarding-link')), findsOneWidget);
    });

    testWidgets('checking it names the helper on a medium-tier case (237)',
        (tester) async {
      when(() => repository.submit(any())).thenAnswer((_) async => const Right(31));
      await pumpPage(tester, owns: false, identified: true, tier: 'medium');

      await tester.tap(find.byKey(const Key('offer-show-name')));
      await tester.pumpAndSettle();
      expect(showNameChecked(tester), isTrue);

      final sent = await submitShare(tester);
      expect(sent.anonymous, isFalse);
    });

    testWidgets('a high-risk case offers NO choice and says the name is never '
        'shown (238)', (tester) async {
      when(() => repository.submit(any())).thenAnswer((_) async => const Right(31));
      await pumpPage(tester, owns: false, identified: true, tier: 'high');

      expect(find.byKey(const Key('offer-show-name')), findsNothing);
      expect(find.byKey(const Key('offer-high-risk-name-notice')), findsOneWidget);
      expect(find.textContaining('High-risk case'), findsOneWidget);

      final sent = await submitShare(tester);
      expect(sent.anonymous, isTrue);
    });

    testWidgets('a tier the form was not told (bare deep link) fails closed: no '
        'choice, the offer goes hidden (238)', (tester) async {
      when(() => repository.submit(any())).thenAnswer((_) async => const Right(31));
      await pumpPage(tester, owns: false, identified: true, tier: null);

      expect(find.byKey(const Key('offer-show-name')), findsNothing);
      expect(find.byKey(const Key('offer-hidden-name-notice')), findsOneWidget);

      final sent = await submitShare(tester);
      expect(sent.anonymous, isTrue);
    });

    testWidgets('without an account there is no name to choose (35)', (tester) async {
      await pumpPage(tester, owns: false, identified: false, tier: 'low');

      expect(find.byKey(const Key('offer-show-name')), findsNothing);
      expect(find.byKey(const Key('offer-high-risk-name-notice')), findsNothing);
      expect(find.byKey(const Key('offer-hidden-name-notice')), findsNothing);
    });
  });

  group('editing the fronts of an existing offer (decision 211)', () {
    const edit = HelpOfferEdit(
      helpOfferId: 31,
      current: {HelpType.share, HelpType.relayInformation},
    );

    testWidgets('opens with the current fronts checked, the edit title and a Save '
        'button — no anonymous notices (an edit is always identified)', (tester) async {
      await pumpPage(tester, owns: false, identified: true, editing: edit);

      expect(find.text('Change help types'), findsOneWidget);
      expect(checked(tester, 'share'), isTrue);
      expect(checked(tester, 'relay_information'), isTrue);
      expect(checked(tester, 'physical_presence'), isFalse);
      expect(find.text('Save'), findsOneWidget);
      expect(find.byKey(const Key('offer-anonymous-notice')), findsNothing);
      // Fronts only (211): the name choice belongs to the new offer.
      expect(find.byKey(const Key('offer-show-name')), findsNothing);
      expect(submitEnabled(tester), isTrue);
      verifyNever(() => repository.submit(any()));
    });

    testWidgets('save PUTs the new set to the same offer and shows the updated view',
        (tester) async {
      when(() => repository.updateTypes(31, {HelpType.share, HelpType.physicalPresence}))
          .thenAnswer((_) async => const Right({HelpType.physicalPresence, HelpType.share}));
      var popped = false;
      await pumpPage(tester,
          owns: false, identified: true, editing: edit, onDone: () => popped = true);

      await tester.tap(find.byKey(const Key('offer-type-relay_information')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('offer-type-physical_presence')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('offer-submit-button')));
      await tester.tap(find.byKey(const Key('offer-submit-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('offer-updated-view')), findsOneWidget);
      expect(find.byKey(const Key('offer-reward-onboarding-link')), findsNothing);
      verify(() => repository.updateTypes(31, {HelpType.share, HelpType.physicalPresence}))
          .called(1);
      verifyNever(() => repository.submit(any()));

      await tester.tap(find.byKey(const Key('offer-done-button')));
      expect(popped, isTrue);
    });

    testWidgets('a resolved case (422) shows the translated error and keeps the form',
        (tester) async {
      when(() => repository.updateTypes(any(), any())).thenAnswer((_) async => const Left(
          Failure(message: 'closed', statusCode: 422, code: 'BUSINESS_RULE')));
      await pumpPage(tester, owns: false, identified: true, editing: edit);

      await tester.ensureVisible(find.byKey(const Key('offer-submit-button')));
      await tester.tap(find.byKey(const Key('offer-submit-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('offer-error')), findsOneWidget);
      expect(submitEnabled(tester), isTrue);
    });
  });
}
