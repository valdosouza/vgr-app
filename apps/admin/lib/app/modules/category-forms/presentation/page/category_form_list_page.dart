import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
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
      appBar: AppBar(title: Text('categoryForms.title'.tr())),
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
                            subtitle: Text(
                              '${field.type.name} · ${field.required ? 'categoryForms.required'.tr() : 'categoryForms.optional'.tr()}',
                            ),
                          ),
                        TextButton(
                          key: Key('add-field-${schema.category}'),
                          onPressed: !SessionAccess.instance
                                  .can('category_forms', Privileges.update)
                              ? null
                              : () => context.read<CategoryFormBloc>().add(
                                FieldAdded(
                                  category: schema.category,
                                  field: const FieldDefinitionEntity(
                                    name: 'newField',
                                    type: FieldType.string,
                                    required: false,
                                  ),
                                ),
                              ),
                          child: Text('categoryForms.addField'.tr()),
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
