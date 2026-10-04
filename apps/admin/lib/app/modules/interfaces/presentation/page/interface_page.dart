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
import '../../domain/entity/interface_entity.dart';
import '../bloc/interface_bloc.dart';

/// The screen catalog (tb_interface — decision 71) on the register
/// factory (PS3): paged list filtered by description / key, form validated
/// as `interfaceSaveDto`, the screen's privileges as a checklist fed by the
/// privilege catalog.
class InterfacePage extends StatelessWidget {
  const InterfacePage({super.key});

  static const screen = CurrentInterface('interfaces');

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PrivilegeOptionsCubit, RegisterLookupState<PrivilegeOption>>(
      builder: (context, lookup) => RegisterScreen<InterfaceEntity, InterfaceDraft>(
        title: 'interfacesScreen.title'.tr(),
        screen: screen,
        rowId: (item) => item.id,
        rowBuilder: (context, item) => RegisterRow(
          title: trCatalog(prefix: 'menu.interfaces', key: item.i18nKey, fallback: item.description),
          subtitle: '${item.i18nKey} · ${item.groupDefault}',
        ),
        formTitle: (current) => current == null
            ? 'interfacesScreen.newTitle'.tr()
            : 'interfacesScreen.editTitle'.tr(args: [current.i18nKey]),
        fields: (current) => [
          RegisterTextField(
            name: 'description',
            label: 'interfacesScreen.description'.tr(),
            initialValue: current?.description ?? '',
            validators: [VgrValidators.minLength(2), VgrValidators.maxLength(120)],
          ),
          RegisterTextField(
            name: 'i18nKey',
            label: 'interfacesScreen.i18nKey'.tr(),
            initialValue: current?.i18nKey ?? '',
            validators: [
              VgrValidators.minLength(2),
              VgrValidators.maxLength(60),
              VgrValidators.lowerSnakeCase,
            ],
          ),
          RegisterTextField(
            name: 'groupDefault',
            label: 'interfacesScreen.groupDefault'.tr(),
            initialValue: current?.groupDefault ?? 'General',
            validators: [VgrValidators.required, VgrValidators.maxLength(60)],
          ),
          RegisterTextField(
            name: 'position',
            label: 'interfacesScreen.position'.tr(),
            initialValue: '${current?.position ?? 0}',
            keyboard: VgrKeyboard.number,
          ),
          RegisterChecklistField(
            name: 'privilegeIds',
            label: 'interfacesScreen.privileges'.tr(),
            initialValue: current?.privilegeIds ?? const [],
            loading: lookup is RegisterLookupLoading<PrivilegeOption>,
            unavailableText: switch (lookup) {
              RegisterLookupFailed<PrivilegeOption>(:final failure) => failureText(failure),
              _ => null,
            },
            options: [
              for (final option in lookup.items)
                VgrOption(
                  value: option.id,
                  label: trCatalog(prefix: 'menu.privileges', key: option.description, fallback: option.description),
                ),
            ],
          ),
        ],
        draftOf: (current, values) {
          final group = values.text('groupDefault').trim();
          return InterfaceDraft(
            description: values.text('description').trim(),
            i18nKey: values.text('i18nKey').trim(),
            groupDefault: group.isEmpty ? 'General' : group,
            kind: current?.kind ?? 'T',
            position: int.tryParse(values.text('position').trim()) ?? 0,
            privilegeIds: values.selection('privilegeIds'),
          );
        },
      ),
    );
  }
}
