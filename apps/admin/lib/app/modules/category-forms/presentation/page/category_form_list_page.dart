import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../domain/entity/field_definition_entity.dart';
import '../../../../shared/feedback/feedback.dart';
import '../bloc/category_form_bloc.dart';
import '../bloc/category_form_event.dart';
import '../bloc/category_form_state.dart';

class CategoryFormListPage extends StatelessWidget {
  const CategoryFormListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final canEdit = SessionAccess.instance.can('category_forms', Privileges.update);

    return VgrPage(
      title: 'categoryForms.title'.tr(),
      padded: false,
      body: BlocConsumer<CategoryFormBloc, CategoryFormState>(
        // Edits answer through the feedback bridge (decision 221); the
        // list never gives way to an error screen because of one.
        listenWhen: (_, state) => state is CategoryFormActionFailed || state is CategoryFormActionSucceeded,
        listener: (context, state) => switch (state) {
          CategoryFormActionFailed(:final failure) => showFailureFeedback(context, failure),
          _ => showSuccessFeedback(context, 'register.saved'.tr()),
        },
        buildWhen: (_, state) => state is! CategoryFormActionFailed && state is! CategoryFormActionSucceeded,
        builder: (context, state) {
          return switch (state) {
            CategoryFormLoading() => const VgrLoading(),
            CategoryFormError(:final failure) => VgrCenter(
                child: VgrColumn(children: [
                  VgrText.error(failureText(failure), key: const Key('catalog-load-error')),
                  const VgrGap.md(),
                  VgrSecondaryButton(
                    key: const Key('catalog-retry-button'),
                    label: 'register.retry'.tr(),
                    onPressed: () => context.read<CategoryFormBloc>().add(const FetchRequested()),
                  ),
                ]),
              ),
            // One-shots never reach the builder (buildWhen).
            CategoryFormActionFailed() || CategoryFormActionSucceeded() => const VgrLoading(),
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
