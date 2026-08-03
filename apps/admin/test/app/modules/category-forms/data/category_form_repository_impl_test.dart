import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/category-forms/data/category_form_repository_impl.dart';
import 'package:vgr_admin/app/modules/category-forms/domain/entity/category_form_schema_entity.dart';
import 'package:vgr_admin/app/modules/category-forms/domain/entity/field_definition_entity.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient apiClient;
  late CategoryFormRepositoryImpl repository;

  const schema = CategoryFormSchemaEntity(
    category: 'missing_person',
    fields: [
      FieldDefinitionEntity(name: 'age', type: FieldType.number, required: true),
      FieldDefinitionEntity(name: 'lastSeenLocation', type: FieldType.string, required: true),
    ],
  );

  setUp(() {
    apiClient = MockApiClient();
    repository = CategoryFormRepositoryImpl(apiClient);
  });

  test('upsert reaches the CategoryFormSchema endpoint and returns Right(unit) on success', () async {
    when(() => apiClient.put('/api/category-forms/missing_person', {
          'fields': [
            {'name': 'age', 'type': 'number', 'required': true},
            {'name': 'lastSeenLocation', 'type': 'string', 'required': true},
          ],
        })).thenAnswer((_) async => {'ok': true, 'data': {}});

    final result = await repository.upsert(schema);

    expect(result, const Right<Failure, Unit>(unit));
  });

  test('list returns Right(schemas) mapped in full from the API response', () async {
    when(() => apiClient.get('/api/category-forms')).thenAnswer(
      (_) async => {
        'ok': true,
        'data': [
          {
            'category': 'missing_person',
            'fields': [
              {'name': 'age', 'type': 'number', 'required': true},
              {'name': 'lastSeenLocation', 'type': 'string', 'required': true},
            ],
          },
        ],
      },
    );

    final result = await repository.list();

    result.fold(
      (failure) => fail('expected Right, got Left($failure)'),
      (schemas) => expect(schemas, [schema]),
    );
  });

  test('upsert converts an ApiClient Failure into Left', () async {
    when(() => apiClient.put(any(), any())).thenThrow(
      const Failure(message: 'Forbidden', statusCode: 403),
    );

    final result = await repository.upsert(schema);

    expect(result, const Left<Failure, Unit>(Failure(message: 'Forbidden', statusCode: 403)));
  });
}
