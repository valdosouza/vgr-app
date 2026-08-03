import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/system_module_entity.dart';
import '../bloc/system_module_bloc.dart';

class SystemModulePage extends StatelessWidget {
  const SystemModulePage({super.key});

  Future<void> _openForm(
    BuildContext context, {
    required List<InterfaceOption> options,
    SystemModuleEntity? current,
  }) async {
    final bloc = context.read<SystemModuleBloc>();
    final description = TextEditingController(text: current?.description ?? '');
    final i18nKey = TextEditingController(text: current?.i18nKey ?? '');
    final imageIcon = TextEditingController(text: current?.imageIcon ?? '');
    final position = TextEditingController(text: '${current?.position ?? 0}');
    // Selection order IS the menu order — a List, not a Set.
    final selected = List<int>.from(current?.interfaceIds ?? const <int>[]);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text('systemModules.title'.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('module-description-field'),
                  controller: description,
                  decoration: InputDecoration(labelText: 'systemModules.description'.tr()),
                ),
                TextField(
                  key: const Key('module-i18nkey-field'),
                  controller: i18nKey,
                  decoration: InputDecoration(labelText: 'systemModules.i18nKey'.tr()),
                ),
                TextField(
                  key: const Key('module-icon-field'),
                  controller: imageIcon,
                  decoration: InputDecoration(labelText: 'systemModules.imageIcon'.tr()),
                ),
                TextField(
                  key: const Key('module-position-field'),
                  controller: position,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'systemModules.position'.tr()),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('systemModules.interfaces'.tr()),
                ),
                for (final option in options)
                  CheckboxListTile(
                    key: Key('module-interface-${option.id}'),
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: selected.contains(option.id),
                    onChanged: (value) => setState(() {
                      value == true ? selected.add(option.id) : selected.remove(option.id);
                    }),
                    title: Text(trCatalog(
                      prefix: 'menu.interfaces',
                      key: option.i18nKey,
                      fallback: option.description,
                    )),
                    // Shows the menu position of a checked screen.
                    secondary: selected.contains(option.id)
                        ? Text('${selected.indexOf(option.id) + 1}')
                        : null,
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
              key: const Key('module-save-button'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('crud.save'.tr()),
            ),
          ],
        ),
      ),
    );

    if (saved == true && description.text.trim().isNotEmpty) {
      final key = i18nKey.text.trim();
      final icon = imageIcon.text.trim();
      bloc.add(SystemModuleSaved(SystemModuleEntity(
        id: current?.id ?? 0,
        description: description.text.trim(),
        i18nKey: key.isEmpty ? null : key,
        imageIcon: icon.isEmpty ? null : icon,
        position: int.tryParse(position.text) ?? 0,
        interfaceIds: selected,
      )));
    }
  }

  Future<void> _confirmDelete(BuildContext context, SystemModuleEntity item) async {
    final bloc = context.read<SystemModuleBloc>();
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
    if (confirmed == true) bloc.add(SystemModuleDeleted(item.id));
  }

  @override
  Widget build(BuildContext context) {
    final canInsert = SessionAccess.instance.can('system_modules', Privileges.insert);
    final canUpdate = SessionAccess.instance.can('system_modules', Privileges.update);
    final canDelete = SessionAccess.instance.can('system_modules', Privileges.delete);

    return Scaffold(
      appBar: AppBar(title: Text('systemModules.title'.tr())),
      body: BlocConsumer<SystemModuleBloc, SystemModuleState>(
        listenWhen: (_, next) => next is SystemModuleLoaded && next.actionError != null,
        listener: (context, state) {
          final message = failureText((state as SystemModuleLoaded).actionError!);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        },
        builder: (context, state) {
          return switch (state) {
            SystemModuleLoading() => const Center(child: CircularProgressIndicator()),
            SystemModuleError(:final message) => Center(child: Text(message)),
            SystemModuleLoaded(:final items, :final interfaceOptions) => Scaffold(
                floatingActionButton: !canInsert
                    ? null
                    : FloatingActionButton(
                        key: const Key('module-new-button'),
                        onPressed: () => _openForm(context, options: interfaceOptions),
                        tooltip: 'crud.new'.tr(),
                        child: const Icon(Icons.add),
                      ),
                body: ListView(
                  children: [
                    for (final item in items)
                      ListTile(
                        key: Key('module-${item.id}'),
                        title: Text(item.i18nKey != null
                            ? trCatalog(
                                prefix: 'menu.modules',
                                key: item.i18nKey!,
                                fallback: item.description,
                              )
                            : item.description),
                        subtitle: Text('${item.interfaceIds.length}'),
                        onTap: !canUpdate
                            ? null
                            : () => _openForm(context, options: interfaceOptions, current: item),
                        trailing: !canDelete
                            ? null
                            : IconButton(
                                key: Key('module-delete-${item.id}'),
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
