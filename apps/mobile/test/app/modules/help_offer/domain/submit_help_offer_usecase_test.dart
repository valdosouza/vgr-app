import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_mobile/app/modules/help_offer/domain/entity/help_offer_entity.dart';
import 'package:vgr_mobile/app/modules/help_offer/domain/repository/help_offer_repository.dart';
import 'package:vgr_mobile/app/modules/help_offer/domain/usecase/submit_help_offer_usecase.dart';

class MockHelpOfferRepository extends Mock implements HelpOfferRepository {}

const _offer = HelpOfferEntity(
  reportId: 5,
  helpType: HelpType.physicalPresence,
  anonymous: true,
);

void main() {
  late MockHelpOfferRepository repository;

  setUp(() {
    repository = MockHelpOfferRepository();
    registerFallbackValue(_offer);
  });

  test('self-dealing (decision 20, spec scenario): Left WITHOUT calling '
      'the repository when this device reported the case', () async {
    final usecase = SubmitHelpOfferUsecase(repository, ownsReport: (_) async => true);

    final result = await usecase(_offer);

    expect(result.fold((f) => f.code, (_) => null), 'SELF_DEALING');
    verifyNever(() => repository.submit(any()));
  });

  test('a non-owner offer goes through and answers the created id', () async {
    when(() => repository.submit(_offer)).thenAnswer((_) async => const Right(31));
    final usecase = SubmitHelpOfferUsecase(repository, ownsReport: (_) async => false);

    final result = await usecase(_offer);

    expect(result, const Right<Failure, int>(31));
  });

  test('a repository failure surfaces unchanged', () async {
    const failure = Failure(message: 'dup', statusCode: 409, code: 'DUPLICATE');
    when(() => repository.submit(_offer)).thenAnswer((_) async => const Left(failure));
    final usecase = SubmitHelpOfferUsecase(repository, ownsReport: (_) async => false);

    final result = await usecase(_offer);

    expect(result, const Left<Failure, int>(failure));
  });
}
