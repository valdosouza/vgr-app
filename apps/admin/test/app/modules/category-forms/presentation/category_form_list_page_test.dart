import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/category-forms/domain/entity/category_form_schema_entity.dart';
import 'package:vgr_admin/app/modules/category-forms/domain/entity/field_definition_entity.dart';
import 'package:vgr_admin/app/modules/category-forms/domain/repository/category_form_repository.dart';
import 'package:vgr_admin/app/modules/category-forms/presentation/bloc/category_form_bloc.dart';
import 'package:vgr_admin/app/modules/category-forms/presentation/bloc/category_form_event.dart';
import 'package:vgr_admin/app/modules/category-forms/presentation/page/category_form_list_page.dart';
import '../../../../helpers/session_access.dart';

class MockCategoryFormRepository extends Mock implements CategoryFormRepository {}

void main() {
  late MockCategoryFormRepository repository;

  const schema = CategoryFormSchemaEntity(
    category: 'missing_person',
    fields: [FieldDefinitionEntity(name: 'age', type: FieldType.number, required: true)],
  );

  setUpAll(() {
    registerFallbackValue(schema);
  });

  setUp(() {
    grantAllPrivileges();
    repository = MockCategoryFormRepository();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => CategoryFormBloc(repository)..add(const FetchRequested()),
          child: const CategoryFormListPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders one section per Category, expandable to its fields', (tester) async {
    when(() => repository.list()).thenAnswer((_) async => const Right([schema]));

    await pumpPage(tester);
    await tester.tap(find.text('missing_person'));
    await tester.pumpAndSettle();

    expect(find.text('age'), findsOneWidget);
  });

  testWidgets('adding a field persists it without re-fetching the whole list', (tester) async {
    when(() => repository.list()).thenAnswer((_) async => const Right([schema]));
    when(() => repository.upsert(any())).thenAnswer((_) async => const Right(unit));

    await pumpPage(tester);
    await tester.tap(find.text('missing_person'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-field-missing_person')));
    await tester.pumpAndSettle();

    verify(() => repository.upsert(any())).called(1);
    verify(() => repository.list()).called(1);
  });
}
