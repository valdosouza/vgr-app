import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;
import 'package:vgr_validators/vgr_validators.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../../shared/register/register_field.dart';
import '../../../../shared/register/register_screen.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../../../shared/session/current_interface.dart';
import '../../domain/entity/user_entity.dart';

/// Team users on the register factory (PS2 pilot — decisions 217/220/221).
/// The form left the dialog: it is the factory's form inside the shell,
/// validated as `userCreateDto` / `userUpdateDto` validate. The initial
/// password is set by the admin (decision 75 — no e-mail invitation); on
/// edit an empty password keeps the current one.
class UserPage extends StatelessWidget {
  const UserPage({super.key});

  static const screen = CurrentInterface('users');

  /// Granting access is its own kind-'R' resource (decision 93), separate
  /// from editing user data.
  static const grants = CurrentInterface('user_privileges');

  static String _nameOf(UserEntity user) => user.name.isEmpty ? user.email : user.name;

  @override
  Widget build(BuildContext context) {
    return RegisterScreen<UserEntity, UserDraft>(
      title: 'users.title'.tr(),
      screen: screen,
      rowId: (user) => user.id,
      rowBuilder: (context, user) => RegisterRow(
        title: _nameOf(user),
        subtitle: user.email,
        leadingIcon: VgrIconName.person,
        trailing: !grants.canView
            ? null
            : VgrIconButton(
                key: Key('user-privileges-${user.id}'),
                icon: VgrIconName.security,
                tooltip: 'users.privilegesOf'.tr(args: [_nameOf(user)]),
                onPressed: () => Modular.to.pushNamed('/users/privileges', arguments: user),
              ),
      ),
      formTitle: (current) => current == null
          ? 'users.newTitle'.tr()
          : 'users.editTitle'.tr(args: [_nameOf(current)]),
      fields: (current) => [
        RegisterTextField(
          name: 'name',
          label: 'users.name'.tr(),
          initialValue: current?.name ?? '',
          validators: [VgrValidators.minLength(2), VgrValidators.maxLength(120)],
        ),
        RegisterTextField(
          name: 'email',
          label: 'users.email'.tr(),
          initialValue: current?.email ?? '',
          keyboard: VgrKeyboard.email,
          validators: [VgrValidators.email, VgrValidators.maxLength(255)],
        ),
        RegisterTextField(
          name: 'password',
          label: 'users.password'.tr(),
          obscure: true,
          hint: current == null ? 'users.passwordPolicyHint'.tr() : 'users.passwordKeepHint'.tr(),
          validators: [
            current == null
                ? VgrValidators.newPassword
                : VgrValidators.optional(VgrValidators.newPassword),
          ],
        ),
        RegisterFlagField(
          name: 'active',
          label: 'users.active'.tr(),
          initialValue: current == null || current.active == 'S',
        ),
      ],
      draftOf: (_, values) {
        final password = values.text('password');
        return UserDraft(
          name: values.text('name').trim(),
          email: values.text('email').trim(),
          active: values.flag('active') ? 'S' : 'N',
          password: password.isEmpty ? null : password,
        );
      },
    );
  }
}
