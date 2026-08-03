import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

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

    final saved = await showVgrDialog<bool>(
      context,
      title: 'interfacesScreen.title'.tr(),
      confirmLabel: 'crud.save'.tr(),
      cancelLabel: 'crud.cancel'.tr(),
      confirmKey: const Key('interface-save-button'),
      content: VgrStatefulContent(
        builder: (context, refresh) => VgrScrollView(
          child: VgrColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VgrTextField(
                key: const Key('interface-description-field'),
                controller: description,
                label: 'interfacesScreen.description'.tr(),
              ),
              VgrTextField(
                key: const Key('interface-i18nkey-field'),
                controller: i18nKey,
                label: 'interfacesScreen.i18nKey'.tr(),
              ),
              VgrTextField(
                key: const Key('interface-group-field'),
                controller: groupDefault,
                label: 'interfacesScreen.groupDefault'.tr(),
              ),
              VgrTextField(
                key: const Key('interface-position-field'),
                controller: position,
                label: 'interfacesScreen.position'.tr(),
                keyboard: VgrKeyboard.number,
              ),
              const VgrGap.sm(),
              VgrText('interfacesScreen.privileges'.tr()),
              for (final option in options)
                VgrCheckboxTile(
                  key: Key('interface-privilege-${option.id}'),
                  value: selected.contains(option.id),
                  label: trCatalog(
                    prefix: 'menu.privileges',
                    key: option.description,
                    fallback: option.description,
                  ),
                  onChanged: (value) => refresh(() {
                    value ? selected.add(option.id) : selected.remove(option.id);
                  }),
                ),
            ],
          ),
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
    final confirmed = await showVgrConfirm(
      context,
      title: 'crud.confirmDeleteTitle'.tr(),
      message: 'crud.confirmDeleteMessage'.tr(),
      confirmLabel: 'crud.delete'.tr(),
      cancelLabel: 'crud.cancel'.tr(),
      destructive: true,
    );
    if (confirmed) bloc.add(InterfaceDeleted(item.id));
  }

  @override
  Widget build(BuildContext context) {
    final canInsert = SessionAccess.instance.can('interfaces', Privileges.insert);
    final canUpdate = SessionAccess.instance.can('interfaces', Privileges.update);
    final canDelete = SessionAccess.instance.can('interfaces', Privileges.delete);

    return BlocConsumer<InterfaceBloc, InterfaceState>(
      listenWhen: (_, next) => next is InterfaceLoaded && next.actionError != null,
      listener: (context, state) {
        showVgrMessage(context, failureText((state as InterfaceLoaded).actionError!));
      },
      builder: (context, state) {
        return VgrScaffold(
          title: 'interfacesScreen.title'.tr(),
          padded: false,
          floatingAction: !canInsert || state is! InterfaceLoaded
              ? null
              : VgrFloatingAddButton(
                  key: const Key('interface-new-button'),
                  onPressed: () => _openForm(context, options: state.privilegeOptions),
                  tooltip: 'crud.new'.tr(),
                ),
          body: switch (state) {
            InterfaceLoading() => const VgrLoading(),
            InterfaceError(:final message) => VgrCenter(child: VgrText.error(message)),
            InterfaceLoaded(:final items, :final privilegeOptions) => VgrListView(
                children: [
                  for (final item in items)
                    VgrListTile(
                      key: Key('interface-${item.id}'),
                      title: trCatalog(
                        prefix: 'menu.interfaces',
                        key: item.i18nKey,
                        fallback: item.description,
                      ),
                      subtitle: '${item.i18nKey} · ${item.groupDefault}',
                      onTap: !canUpdate
                          ? null
                          : () => _openForm(context, options: privilegeOptions, current: item),
                      trailing: !canDelete
                          ? null
                          : VgrIconButton(
                              key: Key('interface-delete-${item.id}'),
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
