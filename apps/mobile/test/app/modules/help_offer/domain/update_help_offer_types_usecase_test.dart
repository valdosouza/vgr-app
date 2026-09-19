import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_mobile/app/modules/help_offer/domain/entity/help_offer_entity.dart';
import 'package:vgr_mobile/app/modules/help_offer/domain/repository/help_offer_repository.dart';
import 'package:vgr_mobile/app/modules/help_offer/domain/usecase/update_help_offer_types_usecase.dart';

class MockHelpOfferRepository extends Mock implements HelpOfferRepository {}

void main() {
  late MockHelpOfferRepository repository;

  setUp(() {
    repository = MockHelpOfferRepository();
  });

  test('an empty set is refused HERE (decision 208, minimum one) — the repository '
      'is never called', () async {
    final usecase = UpdateHelpOfferTypesUsecase(repository);

    final result = await usecase(31, const {});

    expect(result.fold((f) => f.code, (_) => null), 'VALIDATION');
    verifyNever(() => repository.updateTypes(any(), any()));
  });

  test('a non-empty set goes through and answers the stored set', () async {
    when(() => repository.updateTypes(31, {HelpType.share, HelpType.remoteSupport}))
        .thenAnswer((_) async => const Right({HelpType.remoteSupport, HelpType.share}));
    final usecase = UpdateHelpOfferTypesUsecase(repository);

    final result = await usecase(31, {HelpType.share, HelpType.remoteSupport});

    expect(result.getOrElse(() => {}), {HelpType.share, HelpType.remoteSupport});
  });

  test('a repository failure (404 not mine, 422 resolved) surfaces unchanged', () async {
    const failure = Failure(message: 'closed', statusCode: 422, code: 'BUSINESS_RULE');
    when(() => repository.updateTypes(31, {HelpType.share}))
        .thenAnswer((_) async => const Left(failure));
    final usecase = UpdateHelpOfferTypesUsecase(repository);

    final result = await usecase(31, {HelpType.share});

    expect(result, const Left<Failure, Set<HelpType>>(failure));
  });
}
