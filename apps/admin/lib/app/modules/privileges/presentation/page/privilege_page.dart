import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:vgr_validators/vgr_validators.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../../shared/register/register_field.dart';
import '../../../../shared/register/register_screen.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../../../shared/session/current_interface.dart';
import '../../domain/entity/privilege_entity.dart';

/// Privilege catalog on the register factory (PS2 pilot — decisions
/// 217/220/221): paged list filtered by identifier, form with the
/// identifier field validated as the API validates it.
class PrivilegePage extends StatelessWidget {
  const PrivilegePage({super.key});

  static const screen = CurrentInterface('privileges');

  @override
  Widget build(BuildContext context) {
    return RegisterScreen<PrivilegeEntity, PrivilegeDraft>(
      title: 'privileges.title'.tr(),
      screen: screen,
      rowId: (item) => item.id,
      rowBuilder: (context, item) => RegisterRow(
        title: trCatalog(prefix: 'menu.privileges', key: item.description, fallback: item.description),
        subtitle: item.description,
        leadingIcon: VgrIconName.security,
      ),
      formTitle: (current) => current == null
          ? 'privileges.newTitle'.tr()
          : 'privileges.editTitle'.tr(args: [current.description]),
      fields: (current) => [
        RegisterTextField(
          name: 'description',
          label: 'privileges.description'.tr(),
          initialValue: current?.description ?? '',
          // privilegeSaveDto.description: min(2).max(60) + UPPER_SNAKE_CASE.
          validators: [
            VgrValidators.minLength(2),
            VgrValidators.maxLength(60),
            VgrValidators.upperSnakeCase,
          ],
        ),
      ],
      draftOf: (_, values) => PrivilegeDraft(values.text('description').trim()),
    );
  }
}
