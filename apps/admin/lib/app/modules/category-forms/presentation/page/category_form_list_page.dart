import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../domain/entity/field_definition_entity.dart';
import '../bloc/category_form_bloc.dart';
import '../bloc/category_form_event.dart';
import '../bloc/category_form_state.dart';

class CategoryFormListPage extends StatelessWidget {
  const CategoryFormListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final canEdit = SessionAccess.instance.can('category_forms', Privileges.update);

    return VgrScaffold(
      title: 'categoryForms.title'.tr(),
      padded: false,
      body: BlocBuilder<CategoryFormBloc, CategoryFormState>(
        builder: (context, state) {
          return switch (state) {
            CategoryFormLoading() => const VgrLoading(),
            CategoryFormError(:final message) => VgrCenter(child: VgrText.error(message)),
            CategoryFormLoaded(:final schemas) => VgrListView(
                children: [
                  for (final schema in schemas)
                    VgrExpansionTile(
                      title: schema.category,
                      children: [
                        for (final field in schema.fields)
                          VgrListTile(
                            title: field.name,
                            subtitle: '${field.type.name} · '
                                '${field.required ? 'categoryForms.required'.tr() : 'categoryForms.optional'.tr()}',
                          ),
                        VgrTextButton(
                          key: Key('add-field-${schema.category}'),
                          label: 'categoryForms.addField'.tr(),
                          onPressed: !canEdit
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
