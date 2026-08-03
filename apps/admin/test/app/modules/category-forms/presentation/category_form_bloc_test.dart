import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/category-forms/domain/entity/category_form_schema_entity.dart';
import 'package:vgr_admin/app/modules/category-forms/domain/entity/field_definition_entity.dart';
import 'package:vgr_admin/app/modules/category-forms/domain/repository/category_form_repository.dart';
import 'package:vgr_admin/app/modules/category-forms/presentation/bloc/category_form_bloc.dart';
import 'package:vgr_admin/app/modules/category-forms/presentation/bloc/category_form_event.dart';
import 'package:vgr_admin/app/modules/category-forms/presentation/bloc/category_form_state.dart';

class MockCategoryFormRepository extends Mock implements CategoryFormRepository {}

void main() {
  late MockCategoryFormRepository repository;
  late CategoryFormBloc bloc;

  const initialSchema = CategoryFormSchemaEntity(
    category: 'missing_person',
    fields: [FieldDefinitionEntity(name: 'age', type: FieldType.number, required: true)],
  );

  setUpAll(() {
    registerFallbackValue(initialSchema);
  });

  setUp(() {
    repository = MockCategoryFormRepository();
    bloc = CategoryFormBloc(repository);
  });

  tearDown(() => bloc.close());

  test('emits [Loading, Loaded(list)] on initial fetch', () {
    when(() => repository.list()).thenAnswer((_) async => const Right([initialSchema]));

    expectLater(
      bloc.stream,
      emitsInOrder([isA<CategoryFormLoading>(), const CategoryFormLoaded([initialSchema])]),
    );

    bloc.add(const FetchRequested());
  });

  test('appending a field persists the updated schema and updates state without re-fetching', () async {
    when(() => repository.list()).thenAnswer((_) async => const Right([initialSchema]));
    when(() => repository.upsert(any())).thenAnswer((_) async => const Right(unit));

    bloc.add(const FetchRequested());
    await bloc.stream.firstWhere((s) => s is CategoryFormLoaded);

    const newField = FieldDefinitionEntity(name: 'lastSeenLocation', type: FieldType.string, required: true);
    const expectedSchema = CategoryFormSchemaEntity(
      category: 'missing_person',
      fields: [
        FieldDefinitionEntity(name: 'age', type: FieldType.number, required: true),
        newField,
      ],
    );

    expectLater(bloc.stream, emits(const CategoryFormLoaded([expectedSchema])));

    bloc.add(const FieldAdded(category: 'missing_person', field: newField));

    await Future<void>.delayed(Duration.zero);
    verify(() => repository.upsert(expectedSchema)).called(1);
    verify(() => repository.list()).called(1);
  });
}
