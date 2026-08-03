import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/field_definition_entity.dart';
import '../bloc/category_form_bloc.dart';
import '../bloc/category_form_event.dart';
import '../bloc/category_form_state.dart';

class CategoryFormListPage extends StatelessWidget {
  const CategoryFormListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Category Forms')),
      body: BlocBuilder<CategoryFormBloc, CategoryFormState>(
        builder: (context, state) {
          return switch (state) {
            CategoryFormLoading() => const Center(child: CircularProgressIndicator()),
            CategoryFormError(:final message) => Center(child: Text(message)),
            CategoryFormLoaded(:final schemas) => ListView(
                children: [
                  for (final schema in schemas)
                    ExpansionTile(
                      title: Text(schema.category),
                      children: [
                        for (final field in schema.fields)
                          ListTile(
                            title: Text(field.name),
                            subtitle: Text('${field.type.name} · ${field.required ? "required" : "optional"}'),
                          ),
                        TextButton(
                          key: Key('add-field-${schema.category}'),
                          onPressed: () => context.read<CategoryFormBloc>().add(
                                FieldAdded(
                                  category: schema.category,
                                  field: const FieldDefinitionEntity(
                                    name: 'newField',
                                    type: FieldType.string,
                                    required: false,
                                  ),
                                ),
                              ),
                          child: const Text('Add field'),
                        ),
                      ],
                    ),
                ],
              ),
          };
        },
      ),
    );
  }
}
