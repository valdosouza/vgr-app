import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/interface_entity.dart';
import '../bloc/interface_bloc.dart';

class InterfacePage extends StatelessWidget {
  const InterfacePage({super.key});

  Future<void> _openForm(
    BuildContext context, {
    required List<PrivilegeOption> options,
    InterfaceEntity? current,
  }) async {
    final bloc = context.read<InterfaceBloc>();
    final description = TextEditingController(text: current?.description ?? '');
    final i18nKey = TextEditingController(text: current?.i18nKey ?? '');
    final groupDefault = TextEditingController(text: current?.groupDefault ?? 'General');
    final position = TextEditingController(text: '${current?.position ?? 0}');
    final selected = Set<int>.from(current?.privilegeIds ?? const <int>[]);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text('interfacesScreen.title'.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('interface-description-field'),
                  controller: description,
                  decoration: InputDecoration(labelText: 'interfacesScreen.description'.tr()),
                ),
                TextField(
                  key: const Key('interface-i18nkey-field'),
                  controller: i18nKey,
                  decoration: InputDecoration(labelText: 'interfacesScreen.i18nKey'.tr()),
                ),
                TextField(
                  key: const Key('interface-group-field'),
                  controller: groupDefault,
                  decoration: InputDecoration(labelText: 'interfacesScreen.groupDefault'.tr()),
                ),
                TextField(
                  key: const Key('interface-position-field'),
                  controller: position,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'interfacesScreen.position'.tr()),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('interfacesScreen.privileges'.tr()),
                ),
                for (final option in options)
                  CheckboxListTile(
                    key: Key('interface-privilege-${option.id}'),
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: selected.contains(option.id),
                    onChanged: (value) => setState(() {
                      value == true ? selected.add(option.id) : selected.remove(option.id);
                    }),
                    title: Text(trCatalog(
                      prefix: 'menu.privileges',
                      key: option.description,
                      fallback: option.description,
                    )),
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
              key: const Key('interface-save-button'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('crud.save'.tr()),
            ),
          ],
        ),
      ),
    );

    if (saved == true && description.text.trim().isNotEmpty && i18nKey.text.trim().isNotEmpty) {
      bloc.add(InterfaceSaved(InterfaceEntity(
        id: current?.id ?? 0,
        description: description.text.trim(),
        i18nKey: i18nKey.text.trim(),
        groupDefault: groupDefault.text.trim().isEmpty ? 'General' : groupDefault.text.trim(),
        kind: current?.kind ?? 'T',
        position: int.tryParse(position.text) ?? 0,
        privilegeIds: selected.toList()..sort(),
      )));
    }
  }

  Future<void> _confirmDelete(BuildContext context, InterfaceEntity item) async {
    final bloc = context.read<InterfaceBloc>();
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
    if (confirmed == true) bloc.add(InterfaceDeleted(item.id));
  }

  @override
  Widget build(BuildContext context) {
    final canInsert = SessionAccess.instance.can('interfaces', Privileges.insert);
    final canUpdate = SessionAccess.instance.can('interfaces', Privileges.update);
    final canDelete = SessionAccess.instance.can('interfaces', Privileges.delete);

    return Scaffold(
      appBar: AppBar(title: Text('interfacesScreen.title'.tr())),
      body: BlocConsumer<InterfaceBloc, InterfaceState>(
        listenWhen: (_, next) => next is InterfaceLoaded && next.actionError != null,
        listener: (context, state) {
          final message = failureText((state as InterfaceLoaded).actionError!);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        },
        builder: (context, state) {
          return switch (state) {
            InterfaceLoading() => const Center(child: CircularProgressIndicator()),
            InterfaceError(:final message) => Center(child: Text(message)),
            InterfaceLoaded(:final items, :final privilegeOptions) => Scaffold(
                floatingActionButton: !canInsert
                    ? null
                    : FloatingActionButton(
                        key: const Key('interface-new-button'),
                        onPressed: () => _openForm(context, options: privilegeOptions),
                        tooltip: 'crud.new'.tr(),
                        child: const Icon(Icons.add),
                      ),
                body: ListView(
                  children: [
                    for (final item in items)
                      ListTile(
                        key: Key('interface-${item.id}'),
                        title: Text(trCatalog(
                          prefix: 'menu.interfaces',
                          key: item.i18nKey,
                          fallback: item.description,
                        )),
                        subtitle: Text('${item.i18nKey} · ${item.groupDefault}'),
                        onTap: !canUpdate
                            ? null
                            : () => _openForm(context, options: privilegeOptions, current: item),
                        trailing: !canDelete
                            ? null
                            : IconButton(
                                key: Key('interface-delete-${item.id}'),
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _confirmDelete(context, item),
                              ),
                      ),
                  ],
                ),
              ),
          };
        },
      ),
    );
  }
}
