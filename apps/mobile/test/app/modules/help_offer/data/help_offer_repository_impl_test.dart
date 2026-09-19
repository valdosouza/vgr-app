import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_mobile/app/modules/help_offer/data/help_offer_repository_impl.dart';
import 'package:vgr_mobile/app/modules/help_offer/domain/entity/help_offer_entity.dart';

class MockApiClient extends Mock implements ApiClient {}

const _offer = HelpOfferEntity(
  reportId: 5,
  helpTypes: {HelpType.share, HelpType.relayInformation},
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
      // Decision 213: the list only, wire enum values in decision 10's
      // order — never free text, never a singular field.
      'helpTypes': ['relay_information', 'share'],
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

  group('updateTypes — PUT /app-help-offers/:id/types (decision 211)', () {
    test('sends the new set and answers the set the server stored', () async {
      when(() => apiClient.put('/app-help-offers/31/types', any())).thenAnswer(
          (_) async => {'helpOfferId': 31, 'helpTypes': ['physical_presence', 'share']});

      final result = await repository.updateTypes(31, {HelpType.share, HelpType.physicalPresence});

      expect(result.getOrElse(() => {}), {HelpType.physicalPresence, HelpType.share});
      final body = verify(() => apiClient.put('/app-help-offers/31/types', captureAny()))
          .captured
          .single as Map<String, dynamic>;
      expect(body, {'helpTypes': ['physical_presence', 'share']});
    });

    test('an unknown front in the answer is ignored, never a crash', () async {
      when(() => apiClient.put('/app-help-offers/31/types', any())).thenAnswer(
          (_) async => {'helpOfferId': 31, 'helpTypes': ['share', 'teleport']});

      final result = await repository.updateTypes(31, {HelpType.share});

      expect(result.getOrElse(() => {}), {HelpType.share});
    });

    test("someone else's offer is the API's 404 — surfaced by code", () async {
      when(() => apiClient.put('/app-help-offers/31/types', any())).thenThrow(
        const Failure(message: 'nf', statusCode: 404, code: 'NOT_FOUND'),
      );

      final result = await repository.updateTypes(31, {HelpType.share});

      expect(result.fold((f) => f.code, (_) => null), 'NOT_FOUND');
    });

    test('transport failure becomes OFFLINE — never queued', () async {
      when(() => apiClient.put('/app-help-offers/31/types', any()))
          .thenThrow(Exception('socket'));

      final result = await repository.updateTypes(31, {HelpType.share});

      expect(result.fold((f) => f.code, (_) => null), 'OFFLINE');
    });
  });
}
