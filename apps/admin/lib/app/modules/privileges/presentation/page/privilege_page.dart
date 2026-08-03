import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/privilege_entity.dart';
import '../bloc/privilege_bloc.dart';

class PrivilegePage extends StatelessWidget {
  const PrivilegePage({super.key});

  Future<void> _openForm(BuildContext context, {PrivilegeEntity? current}) async {
    final bloc = context.read<PrivilegeBloc>();
    final controller = TextEditingController(text: current?.description ?? '');

    final description = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('privileges.title'.tr()),
        content: TextField(
          key: const Key('privilege-description-field'),
          controller: controller,
          decoration: InputDecoration(labelText: 'privileges.description'.tr()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('crud.cancel'.tr()),
          ),
          ElevatedButton(
            key: const Key('privilege-save-button'),
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text('crud.save'.tr()),
          ),
        ],
      ),
    );

    if (description != null && description.isNotEmpty) {
      bloc.add(PrivilegeSaved(id: current?.id, description: description));
    }
  }

  Future<void> _confirmDelete(BuildContext context, PrivilegeEntity item) async {
    final bloc = context.read<PrivilegeBloc>();
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
            key: const Key('privilege-confirm-delete-button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('crud.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true) bloc.add(PrivilegeDeleted(item.id));
  }

  @override
  Widget build(BuildContext context) {
    final canInsert = SessionAccess.instance.can('privileges', Privileges.insert);
    final canUpdate = SessionAccess.instance.can('privileges', Privileges.update);
    final canDelete = SessionAccess.instance.can('privileges', Privileges.delete);

    return Scaffold(
      appBar: AppBar(title: Text('privileges.title'.tr())),
      floatingActionButton: !canInsert
          ? null
          : FloatingActionButton(
              key: const Key('privilege-new-button'),
              onPressed: () => _openForm(context),
              tooltip: 'crud.new'.tr(),
              child: const Icon(Icons.add),
            ),
      body: BlocConsumer<PrivilegeBloc, PrivilegeState>(
        listenWhen: (_, next) => next is PrivilegeLoaded && next.actionError != null,
        listener: (context, state) {
          // Translated by catalog code (decisions 80/83).
          final message = failureText((state as PrivilegeLoaded).actionError!);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        },
        builder: (context, state) {
          return switch (state) {
            PrivilegeLoading() => const Center(child: CircularProgressIndicator()),
            PrivilegeError(:final message) => Center(child: Text(message)),
            PrivilegeLoaded(:final items) => ListView(
                children: [
                  for (final item in items)
                    ListTile(
                      key: Key('privilege-${item.id}'),
                      title: Text(trCatalog(
                        prefix: 'menu.privileges',
                        key: item.description,
                        fallback: item.description,
                      )),
                      subtitle: Text(item.description),
                      onTap: !canUpdate ? null : () => _openForm(context, current: item),
                      trailing: !canDelete
                          ? null
                          : IconButton(
                              key: Key('privilege-delete-${item.id}'),
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _confirmDelete(context, item),
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
