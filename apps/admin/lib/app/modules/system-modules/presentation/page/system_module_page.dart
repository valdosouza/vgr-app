import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

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

    final saved = await showVgrDialog<bool>(
      context,
      title: 'systemModules.title'.tr(),
      confirmLabel: 'crud.save'.tr(),
      cancelLabel: 'crud.cancel'.tr(),
      confirmKey: const Key('module-save-button'),
      content: VgrStatefulContent(
        builder: (context, refresh) => VgrScrollView(
          child: VgrColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VgrTextField(
                key: const Key('module-description-field'),
                controller: description,
                label: 'systemModules.description'.tr(),
              ),
              VgrTextField(
                key: const Key('module-i18nkey-field'),
                controller: i18nKey,
                label: 'systemModules.i18nKey'.tr(),
              ),
              VgrTextField(
                key: const Key('module-icon-field'),
                controller: imageIcon,
                label: 'systemModules.imageIcon'.tr(),
              ),
              VgrTextField(
                key: const Key('module-position-field'),
                controller: position,
                label: 'systemModules.position'.tr(),
                keyboard: VgrKeyboard.number,
              ),
              const VgrGap.sm(),
              VgrText('systemModules.interfaces'.tr()),
              for (final option in options)
                VgrCheckboxTile(
                  key: Key('module-interface-${option.id}'),
                  value: selected.contains(option.id),
                  label: trCatalog(
                    prefix: 'menu.interfaces',
                    key: option.i18nKey,
                    fallback: option.description,
                  ),
                  // Shows the menu position of a checked screen.
                  trailingText: selected.contains(option.id)
                      ? '${selected.indexOf(option.id) + 1}'
                      : null,
                  onChanged: (value) => refresh(() {
                    value ? selected.add(option.id) : selected.remove(option.id);
                  }),
                ),
            ],
          ),
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
    final confirmed = await showVgrConfirm(
      context,
      title: 'crud.confirmDeleteTitle'.tr(),
      message: 'crud.confirmDeleteMessage'.tr(),
      confirmLabel: 'crud.delete'.tr(),
      cancelLabel: 'crud.cancel'.tr(),
      destructive: true,
    );
    if (confirmed) bloc.add(SystemModuleDeleted(item.id));
  }

  @override
  Widget build(BuildContext context) {
    final canInsert = SessionAccess.instance.can('system_modules', Privileges.insert);
    final canUpdate = SessionAccess.instance.can('system_modules', Privileges.update);
    final canDelete = SessionAccess.instance.can('system_modules', Privileges.delete);

    return BlocConsumer<SystemModuleBloc, SystemModuleState>(
      listenWhen: (_, next) => next is SystemModuleLoaded && next.actionError != null,
      listener: (context, state) {
        showVgrMessage(context, failureText((state as SystemModuleLoaded).actionError!));
      },
      builder: (context, state) {
        return VgrScaffold(
          title: 'systemModules.title'.tr(),
          padded: false,
          floatingAction: !canInsert || state is! SystemModuleLoaded
              ? null
              : VgrFloatingAddButton(
                  key: const Key('module-new-button'),
                  onPressed: () => _openForm(context, options: state.interfaceOptions),
                  tooltip: 'crud.new'.tr(),
                ),
          body: switch (state) {
            SystemModuleLoading() => const VgrLoading(),
            SystemModuleError(:final message) => VgrCenter(child: VgrText.error(message)),
            SystemModuleLoaded(:final items, :final interfaceOptions) => VgrListView(
                children: [
                  for (final item in items)
                    VgrListTile(
                      key: Key('module-${item.id}'),
                      title: item.i18nKey != null
                          ? trCatalog(
                              prefix: 'menu.modules',
                              key: item.i18nKey!,
                              fallback: item.description,
                            )
                          : item.description,
                      subtitle: '${item.interfaceIds.length}',
                      onTap: !canUpdate
                          ? null
                          : () => _openForm(context, options: interfaceOptions, current: item),
                      trailing: !canDelete
                          ? null
                          : VgrIconButton(
                              key: Key('module-delete-${item.id}'),
                              icon: VgrIconName.delete,
                              tooltip: 'crud.delete'.tr(),
                              onPressed: () => _confirmDelete(context, item),
                            ),
                    ),
                ],
              ),
          },
        );
      },
    );
  }
}
