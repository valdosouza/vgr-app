import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../domain/entity/user_entity.dart';
import '../bloc/user_bloc.dart';

class UserPage extends StatelessWidget {
  const UserPage({super.key});

  Future<void> _openForm(BuildContext context, {UserEntity? current}) async {
    final bloc = context.read<UserBloc>();
    final name = TextEditingController(text: current?.name ?? '');
    final email = TextEditingController(text: current?.email ?? '');
    final password = TextEditingController();
    var active = current == null || current.active == 'S';

    final saved = await showVgrDialog<bool>(
      context,
      title: 'users.title'.tr(),
      content: VgrStatefulContent(
        builder: (context, refresh) => VgrScrollView(
          child: VgrColumn(
            children: [
              VgrTextField(
                key: const Key('user-name-field'),
                controller: name,
                label: 'users.name'.tr(),
              ),
              VgrTextField(
                key: const Key('user-email-field'),
                controller: email,
                label: 'users.email'.tr(),
                keyboard: VgrKeyboard.email,
              ),
              VgrTextField(
                key: const Key('user-password-field'),
                controller: password,
                label: 'users.password'.tr(),
                obscure: true,
                helperText: current == null ? null : 'users.passwordKeepHint'.tr(),
              ),
              VgrSwitchTile(
                key: const Key('user-active-switch'),
                value: active,
                label: 'users.active'.tr(),
                onChanged: (value) => refresh(() => active = value),
              ),
            ],
          ),
        ),
      ),
      confirmLabel: 'crud.save'.tr(),
      cancelLabel: 'crud.cancel'.tr(),
      confirmKey: const Key('user-save-button'),
    );

    if (saved == true && name.text.trim().isNotEmpty && email.text.trim().isNotEmpty) {
      bloc.add(UserSaved(
        id: current?.id,
        name: name.text.trim(),
        email: email.text.trim(),
        active: active ? 'S' : 'N',
        password: password.text.isEmpty ? null : password.text,
      ));
    }
  }

  Future<void> _confirmDelete(BuildContext context, UserEntity user) async {
    final bloc = context.read<UserBloc>();
    final confirmed = await showVgrConfirm(
      context,
      title: 'crud.confirmDeleteTitle'.tr(),
      message: 'crud.confirmDeleteMessage'.tr(),
      confirmLabel: 'crud.delete'.tr(),
      cancelLabel: 'crud.cancel'.tr(),
      destructive: true,
    );
    if (confirmed) bloc.add(UserDeleted(user.id));
  }

  @override
  Widget build(BuildContext context) {
    final canInsert = SessionAccess.instance.can('users', Privileges.insert);
    final canUpdate = SessionAccess.instance.can('users', Privileges.update);
    final canDelete = SessionAccess.instance.can('users', Privileges.delete);
    // Granting access is its own kind-'R' resource (decision 93), separate
    // from editing user data.
    final canSeeGrants = SessionAccess.instance.can('user_privileges', Privileges.view);

    return VgrScaffold(
      title: 'users.title'.tr(),
      padded: false,
      floatingAction: !canInsert
          ? null
          : VgrFloatingAddButton(
              key: const Key('user-new-button'),
              onPressed: () => _openForm(context),
              tooltip: 'crud.new'.tr(),
            ),
      body: BlocConsumer<UserBloc, UserState>(
        listenWhen: (_, next) => next is UserLoaded && next.actionError != null,
        listener: (context, state) {
          showVgrMessage(context, failureText((state as UserLoaded).actionError!));
        },
        builder: (context, state) {
          return switch (state) {
            UserLoading() => const VgrLoading(),
            UserError(:final message) => VgrCenter(child: VgrText.error(message)),
            UserLoaded(:final items) => VgrListView(
                children: [
                  for (final user in items)
                    VgrListTile(
                      key: Key('user-${user.id}'),
                      leadingIcon: VgrIconName.person,
                      title: user.name.isEmpty ? user.email : user.name,
                      subtitle: user.email,
                      onTap: !canUpdate ? null : () => _openForm(context, current: user),
                      trailing: VgrRow(
                        children: [
                          if (canSeeGrants)
                            VgrIconButton(
                              key: Key('user-privileges-${user.id}'),
                              icon: VgrIconName.security,
                              tooltip: 'users.privilegesOf'.tr(args: [user.name]),
                              onPressed: () =>
                                  Modular.to.pushNamed('/users/privileges', arguments: user),
                            ),
                          if (canDelete)
                            VgrIconButton(
                              key: Key('user-delete-${user.id}'),
                              icon: VgrIconName.delete,
                              tooltip: 'crud.delete'.tr(),
                              onPressed: () => _confirmDelete(context, user),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
          };
        },
      ),
    );
  }
}
