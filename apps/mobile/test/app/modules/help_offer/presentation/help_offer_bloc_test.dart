import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_mobile/app/modules/help_offer/domain/entity/help_offer_entity.dart';
import 'package:vgr_mobile/app/modules/help_offer/domain/repository/help_offer_repository.dart';
import 'package:vgr_mobile/app/modules/help_offer/domain/usecase/submit_help_offer_usecase.dart';
import 'package:vgr_mobile/app/modules/help_offer/presentation/bloc/help_offer_bloc.dart';

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

  HelpOfferBloc build({required bool owns}) => HelpOfferBloc(
        SubmitHelpOfferUsecase(repository, ownsReport: (_) async => owns),
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
      ..add(const HelpOfferTypeSelected(HelpType.share))
      ..add(const HelpOfferSubmitPressed(anonymous: true));
    await settle();

    expect(bloc.state, const HelpOfferBlockedSelfDealing());
    verifyNever(() => repository.submit(any()));
  });

  test('select → submit posts the chosen type and succeeds', () async {
    when(() => repository.submit(any())).thenAnswer((_) async => const Right(31));

    final bloc = build(owns: false)..add(const HelpOfferStarted(5));
    await settle();
    bloc.add(const HelpOfferTypeSelected(HelpType.remoteSupport));
    await settle();
    bloc.add(const HelpOfferSubmitPressed(anonymous: true));
    await settle();

    expect(bloc.state, const HelpOfferSuccess(31));
    final sent = verify(() => repository.submit(captureAny())).captured.single
        as HelpOfferEntity;
    expect(sent.reportId, 5);
    expect(sent.helpType, HelpType.remoteSupport);
    expect(sent.anonymous, isTrue);
  });

  test('submit without a selected type is a no-op', () async {
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
    bloc.add(const HelpOfferTypeSelected(HelpType.share));
    await settle();
    bloc.add(const HelpOfferSubmitPressed(anonymous: true));
    await settle();

    expect(bloc.state,
        const HelpOfferReady(selected: HelpType.share, failure: failure));
  });
}
