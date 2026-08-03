import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/user_entity.dart';
import '../bloc/user_privileges_bloc.dart';

/// Matrix screen × privilege for one team user (mirrors setes'
/// user_privileges_section): checking any privilege implies VIEW — the rule
/// lives in the API; this page just re-fetches to reflect it.
class UserPrivilegesPage extends StatelessWidget {
  const UserPrivilegesPage({super.key, required this.user});

  final UserEntity user;

  @override
  Widget build(BuildContext context) {
    // kind-'R' resource (decision 93): seeing the matrix needs VIEW; the
    // checkboxes only respond with UPDATE (the API enforces both anyway).
    final canGrant = SessionAccess.instance.can('user_privileges', Privileges.update);

    return Scaffold(
      appBar: AppBar(
        title: Text('users.privilegesOf'.tr(args: [user.name.isEmpty ? user.email : user.name])),
      ),
      body: BlocConsumer<UserPrivilegesBloc, UserPrivilegesState>(
        listenWhen: (_, next) =>
            next is UserPrivilegesLoaded && (next.actionError != null || next.saved),
        listener: (context, state) {
          final loaded = state as UserPrivilegesLoaded;
          final message = loaded.actionError != null
              ? failureText(loaded.actionError!)
              : 'users.grantsSaved'.tr();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        },
        builder: (context, state) {
          return switch (state) {
            UserPrivilegesLoading() => const Center(child: CircularProgressIndicator()),
            UserPrivilegesError(:final message) => Center(child: Text(message)),
            UserPrivilegesLoaded(:final matrix) => ListView(
                children: [
                  for (final screen in matrix)
                    ExpansionTile(
                      key: Key('grants-${screen.interfaceKey}'),
                      title: Text(trCatalog(
                        prefix: 'menu.interfaces',
                        key: screen.interfaceKey,
                        fallback: screen.description,
                      )),
                      subtitle: Text(
                        screen.privileges
                            .where((p) => p.granted)
                            .map((p) => trCatalog(
                                  prefix: 'menu.privileges',
                                  key: p.description,
                                  fallback: p.description,
                                ))
                            .join(' · '),
                      ),
                      children: [
                        for (final cell in screen.privileges)
                          CheckboxListTile(
                            key: Key('grant-${screen.interfaceKey}-${cell.description}'),
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: cell.granted,
                            onChanged: !canGrant
                                ? null
                                : (value) {
                              final granted = screen.privileges
                                  .where((p) => p.granted)
                                  .map((p) => p.privilegeId)
                                  .toSet();
                              value == true
                                  ? granted.add(cell.privilegeId)
                                  : granted.remove(cell.privilegeId);
                              context.read<UserPrivilegesBloc>().add(
                                    UserInterfaceGrantsSubmitted(
                                      userId: user.id,
                                      interfaceId: screen.interfaceId,
                                      privilegeIds: granted.toList(),
                                    ),
                                  );
                            },
                            title: Text(trCatalog(
                              prefix: 'menu.privileges',
                              key: cell.description,
                              fallback: cell.description,
                            )),
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
