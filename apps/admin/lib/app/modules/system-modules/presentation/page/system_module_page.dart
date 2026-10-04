import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vgr_validators/vgr_validators.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../../shared/register/register_field.dart';
import '../../../../shared/register/register_screen.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../../../shared/session/current_interface.dart';
import '../../domain/entity/system_module_entity.dart';
import '../bloc/system_module_bloc.dart';

/// Menu modules (tb_module — decision 71, the CRUD setes never had) on the
/// register factory (PS3): paged list filtered by description, form
/// validated as `systemModuleSaveDto`, the module's screens as an ORDERED
/// checklist — the order of checking is the menu order.
class SystemModulePage extends StatelessWidget {
  const SystemModulePage({super.key});

  static const screen = CurrentInterface('system_modules');

  static String _optional(String text) => text.trim();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InterfaceOptionsCubit, RegisterLookupState<InterfaceOption>>(
      builder: (context, lookup) => RegisterScreen<SystemModuleEntity, SystemModuleDraft>(
        title: 'systemModules.title'.tr(),
        screen: screen,
        rowId: (item) => item.id,
        rowBuilder: (context, item) => RegisterRow(
          title: item.i18nKey != null
              ? trCatalog(prefix: 'menu.modules', key: item.i18nKey!, fallback: item.description)
              : item.description,
          subtitle: 'systemModules.screenCount'.tr(args: ['${item.interfaceIds.length}']),
          leadingIcon: VgrIconName.menu,
        ),
        formTitle: (current) => current == null
            ? 'systemModules.newTitle'.tr()
            : 'systemModules.editTitle'.tr(args: [current.description]),
        fields: (current) => [
          RegisterTextField(
            name: 'description',
            label: 'systemModules.description'.tr(),
            initialValue: current?.description ?? '',
            validators: [VgrValidators.minLength(2), VgrValidators.maxLength(120)],
          ),
          RegisterTextField(
            name: 'i18nKey',
            label: 'systemModules.i18nKey'.tr(),
            initialValue: current?.i18nKey ?? '',
            // Optional, but when given it follows the same key discipline.
            validators: [
              VgrValidators.optional(VgrValidators.minLength(2)),
              VgrValidators.maxLength(60),
              VgrValidators.optional(VgrValidators.lowerSnakeCase),
            ],
          ),
          RegisterTextField(
            name: 'imageIcon',
            label: 'systemModules.imageIcon'.tr(),
            initialValue: current?.imageIcon ?? '',
            validators: [VgrValidators.maxLength(60)],
          ),
          RegisterTextField(
            name: 'position',
            label: 'systemModules.position'.tr(),
            initialValue: '${current?.position ?? 0}',
            keyboard: VgrKeyboard.number,
          ),
          RegisterChecklistField(
            name: 'interfaceIds',
            label: 'systemModules.interfaces'.tr(),
            ordered: true,
            initialValue: current?.interfaceIds ?? const [],
            loading: lookup is RegisterLookupLoading<InterfaceOption>,
            unavailableText: switch (lookup) {
              RegisterLookupFailed<InterfaceOption>(:final failure) => failureText(failure),
              _ => null,
            },
            options: [
              for (final option in lookup.items)
                VgrOption(
                  value: option.id,
                  label: trCatalog(prefix: 'menu.interfaces', key: option.i18nKey, fallback: option.description),
                ),
            ],
          ),
        ],
        draftOf: (_, values) {
          final key = _optional(values.text('i18nKey'));
          final icon = _optional(values.text('imageIcon'));
          return SystemModuleDraft(
            description: values.text('description').trim(),
            i18nKey: key.isEmpty ? null : key,
            imageIcon: icon.isEmpty ? null : icon,
            position: int.tryParse(values.text('position').trim()) ?? 0,
            interfaceIds: values.selection('interfaceIds'),
          );
        },
      ),
    );
  }
}
