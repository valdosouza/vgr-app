import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_mobile/app/modules/help_offer/domain/entity/help_offer_entity.dart';
import 'package:vgr_mobile/app/modules/help_offer/domain/repository/help_offer_repository.dart';
import 'package:vgr_mobile/app/modules/help_offer/domain/usecase/submit_help_offer_usecase.dart';
import 'package:vgr_mobile/app/modules/help_offer/domain/usecase/update_help_offer_types_usecase.dart';
import 'package:vgr_mobile/app/modules/help_offer/presentation/bloc/help_offer_bloc.dart';

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

  HelpOfferBloc build({required bool owns}) => HelpOfferBloc(
        SubmitHelpOfferUsecase(repository, ownsReport: (_) async => owns),
        UpdateHelpOfferTypesUsecase(repository),
        ownsReport: (_) async => owns,
      );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('own report: Blocked WITHOUT calling the repository (spec scenario, '
      'decision 20)', () async {
    final bloc = build(owns: true)..add(const HelpOfferStarted(5));
    await settle();

    expect(bloc.state, const HelpOfferBlockedSelfDealing());
    verifyNever(() => repository.submit(any()));
  });

  test('blocked form ignores selection and submit', () async {
    final bloc = build(owns: true)..add(const HelpOfferStarted(5));
    await settle();

    bloc
      ..add(const HelpOfferTypeToggled(HelpType.share))
      ..add(const HelpOfferSubmitPressed(anonymous: true));
    await settle();

    expect(bloc.state, const HelpOfferBlockedSelfDealing());
    verifyNever(() => repository.submit(any()));
  });

  test('toggling accumulates a SET — two fronts stay checked together (decision 208)',
      () async {
    final bloc = build(owns: false)..add(const HelpOfferStarted(5));
    await settle();
    bloc
      ..add(const HelpOfferTypeToggled(HelpType.share))
      ..add(const HelpOfferTypeToggled(HelpType.remoteSupport));
    await settle();

    expect(bloc.state,
        const HelpOfferReady(selected: {HelpType.share, HelpType.remoteSupport}));
  });

  test('toggling a checked front removes only that one', () async {
    final bloc = build(owns: false)..add(const HelpOfferStarted(5));
    await settle();
    bloc
      ..add(const HelpOfferTypeToggled(HelpType.share))
      ..add(const HelpOfferTypeToggled(HelpType.remoteSupport))
      ..add(const HelpOfferTypeToggled(HelpType.share));
    await settle();

    expect(bloc.state, const HelpOfferReady(selected: {HelpType.remoteSupport}));
  });

  test('select → submit posts the whole set and succeeds', () async {
    when(() => repository.submit(any())).thenAnswer((_) async => const Right(31));

    final bloc = build(owns: false)..add(const HelpOfferStarted(5));
    await settle();
    bloc
      ..add(const HelpOfferTypeToggled(HelpType.remoteSupport))
      ..add(const HelpOfferTypeToggled(HelpType.physicalPresence));
    await settle();
    bloc.add(const HelpOfferSubmitPressed(anonymous: true));
    await settle();

    expect(bloc.state, const HelpOfferSuccess(31));
    final sent = verify(() => repository.submit(captureAny())).captured.single
        as HelpOfferEntity;
    expect(sent.reportId, 5);
    expect(sent.helpTypes, {HelpType.remoteSupport, HelpType.physicalPresence});
    expect(sent.anonymous, isTrue);
  });

  test('submit with nothing selected is a no-op (208: minimum one)', () async {
    final bloc = build(owns: false)..add(const HelpOfferStarted(5));
    await settle();
    bloc.add(const HelpOfferSubmitPressed(anonymous: true));
    await settle();

    expect(bloc.state, const HelpOfferReady());
    verifyNever(() => repository.submit(any()));
  });

  test('a failure keeps the selection so the user can retry', () async {
    const failure = Failure(message: 'dup', statusCode: 409, code: 'DUPLICATE');
    when(() => repository.submit(any())).thenAnswer((_) async => const Left(failure));

    final bloc = build(owns: false)..add(const HelpOfferStarted(5));
    await settle();
    bloc.add(const HelpOfferTypeToggled(HelpType.share));
    await settle();
    bloc.add(const HelpOfferSubmitPressed(anonymous: true));
    await settle();

    expect(bloc.state,
        const HelpOfferReady(selected: {HelpType.share}, failure: failure));
  });

  group('editing an existing offer (decision 211)', () {
    test('opens Ready with the current set checked, without the ownership check',
        () async {
      // owns: true would block a NEW offer — an edit never consults it,
      // because the server only serves `myOffer` to a participant.
      final bloc = build(owns: true)
        ..add(const HelpOfferEditStarted(
            helpOfferId: 31, current: {HelpType.share, HelpType.relayInformation}));
      await settle();

      expect(bloc.state,
          const HelpOfferReady(selected: {HelpType.share, HelpType.relayInformation}));
    });

    test('submit PUTs the new set to the SAME offer, never a new POST', () async {
      when(() => repository.updateTypes(31, {HelpType.share, HelpType.remoteSupport}))
          .thenAnswer((_) async => const Right({HelpType.remoteSupport, HelpType.share}));

      final bloc = build(owns: false)
        ..add(const HelpOfferEditStarted(helpOfferId: 31, current: {HelpType.share}));
      await settle();
      bloc.add(const HelpOfferTypeToggled(HelpType.remoteSupport));
      await settle();
      bloc.add(const HelpOfferSubmitPressed(anonymous: false));
      await settle();

      expect(bloc.state,
          const HelpOfferTypesUpdated({HelpType.remoteSupport, HelpType.share}));
      verifyNever(() => repository.submit(any()));
    });

    test('unchecking everything disables submit — the edit is a no-op', () async {
      final bloc = build(owns: false)
        ..add(const HelpOfferEditStarted(helpOfferId: 31, current: {HelpType.share}));
      await settle();
      bloc.add(const HelpOfferTypeToggled(HelpType.share));
      await settle();
      bloc.add(const HelpOfferSubmitPressed(anonymous: false));
      await settle();

      expect(bloc.state, const HelpOfferReady());
      verifyNever(() => repository.updateTypes(any(), any()));
    });

    test('a refusal (resolved case, 422) keeps the selection for retry', () async {
      const failure = Failure(message: 'closed', statusCode: 422, code: 'BUSINESS_RULE');
      when(() => repository.updateTypes(31, {HelpType.share}))
          .thenAnswer((_) async => const Left(failure));

      final bloc = build(owns: false)
        ..add(const HelpOfferEditStarted(helpOfferId: 31, current: {HelpType.share}));
      await settle();
      bloc.add(const HelpOfferSubmitPressed(anonymous: false));
      await settle();

      expect(bloc.state, const HelpOfferReady(selected: {HelpType.share}, failure: failure));
    });
  });
}
