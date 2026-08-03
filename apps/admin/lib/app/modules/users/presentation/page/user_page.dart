import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;

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

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text('users.title'.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('user-name-field'),
                  controller: name,
                  decoration: InputDecoration(labelText: 'users.name'.tr()),
                ),
                TextField(
                  key: const Key('user-email-field'),
                  controller: email,
                  decoration: InputDecoration(labelText: 'users.email'.tr()),
                ),
                TextField(
                  key: const Key('user-password-field'),
                  controller: password,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'users.password'.tr(),
                    helperText: current == null ? null : 'users.passwordKeepHint'.tr(),
                  ),
                ),
                SwitchListTile(
                  key: const Key('user-active-switch'),
                  value: active,
                  onChanged: (value) => setState(() => active = value),
                  title: Text('users.active'.tr()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('crud.cancel'.tr()),
            ),
            ElevatedButton(
              key: const Key('user-save-button'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('crud.save'.tr()),
            ),
          ],
        ),
      ),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('crud.confirmDeleteTitle'.tr()),
        content: Text('crud.confirmDeleteMessage'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('crud.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('crud.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true) bloc.add(UserDeleted(user.id));
  }

  @override
  Widget build(BuildContext context) {
    final canInsert = SessionAccess.instance.can('users', Privileges.insert);
    final canUpdate = SessionAccess.instance.can('users', Privileges.update);
    final canDelete = SessionAccess.instance.can('users', Privileges.delete);
    // Granting access is its own kind-'R' resource (decision 93), separate
    // from editing user data.
    final canSeeGrants = SessionAccess.instance.can('user_privileges', Privileges.view);

    return Scaffold(
      appBar: AppBar(title: Text('users.title'.tr())),
      floatingActionButton: !canInsert
          ? null
          : FloatingActionButton(
              key: const Key('user-new-button'),
              onPressed: () => _openForm(context),
              tooltip: 'crud.new'.tr(),
              child: const Icon(Icons.add),
            ),
      body: BlocConsumer<UserBloc, UserState>(
        listenWhen: (_, next) => next is UserLoaded && next.actionError != null,
        listener: (context, state) {
          final message = failureText((state as UserLoaded).actionError!);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        },
        builder: (context, state) {
          return switch (state) {
            UserLoading() => const Center(child: CircularProgressIndicator()),
            UserError(:final message) => Center(child: Text(message)),
            UserLoaded(:final items) => ListView(
                children: [
                  for (final user in items)
                    ListTile(
                      key: Key('user-${user.id}'),
                      leading: Icon(
                        user.active == 'S' ? Icons.person : Icons.person_off,
                      ),
                      title: Text(user.name.isEmpty ? user.email : user.name),
                      subtitle: Text(user.email),
                      onTap: !canUpdate ? null : () => _openForm(context, current: user),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (canSeeGrants)
                            IconButton(
                              key: Key('user-privileges-${user.id}'),
                              tooltip: 'users.privilegesOf'.tr(args: [user.name]),
                              icon: const Icon(Icons.lock_open),
                              onPressed: () =>
                                  Modular.to.pushNamed('/users/privileges', arguments: user),
                            ),
                          if (canDelete)
                            IconButton(
                              key: Key('user-delete-${user.id}'),
                              icon: const Icon(Icons.delete_outline),
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
