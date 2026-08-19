import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_mobile/app/modules/help_offer/data/help_offer_repository_impl.dart';
import 'package:vgr_mobile/app/modules/help_offer/domain/entity/help_offer_entity.dart';

class MockApiClient extends Mock implements ApiClient {}

const _offer = HelpOfferEntity(
  reportId: 5,
  helpType: HelpType.relayInformation,
  anonymous: true,
);

void main() {
  late MockApiClient apiClient;
  late HelpOfferRepositoryImpl repository;

  setUp(() {
    apiClient = MockApiClient();
    repository = HelpOfferRepositoryImpl(apiClient);
  });

  test('posts to /app-help-offers on the app plane and answers the id', () async {
    when(() => apiClient.post('/app-help-offers', any()))
        .thenAnswer((_) async => {'helpOfferId': 31});

    final result = await repository.submit(_offer);

    expect(result.getOrElse(() => -1), 31);
    final body = verify(() => apiClient.post('/app-help-offers', captureAny()))
        .captured
        .single as Map<String, dynamic>;
    expect(body, {
      'reportId': 5,
      'helpType': 'relay_information', // the wire enum, never free text
      'anonymous': true,
    });
  });

  test('a duplicate offer (409, decision 20 family) surfaces as Left', () async {
    when(() => apiClient.post('/app-help-offers', any())).thenThrow(
      const Failure(message: 'dup', statusCode: 409, code: 'DUPLICATE'),
    );

    final result = await repository.submit(_offer);

    expect(result.fold((f) => f.code, (_) => null), 'DUPLICATE');
  });

  test('transport failure becomes OFFLINE — offers never ride the queue '
      '(amendment MA10)', () async {
    when(() => apiClient.post('/app-help-offers', any()))
        .thenThrow(Exception('socket'));

    final result = await repository.submit(_offer);

    expect(result.fold((f) => f.code, (_) => null), 'OFFLINE');
  });
}
