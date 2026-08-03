import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../domain/entity/privilege_entity.dart';
import '../bloc/privilege_bloc.dart';

class PrivilegePage extends StatelessWidget {
  const PrivilegePage({super.key});

  Future<void> _openForm(BuildContext context, {PrivilegeEntity? current}) async {
    final bloc = context.read<PrivilegeBloc>();
    final description = await showVgrTextPrompt(
      context,
      title: 'privileges.title'.tr(),
      label: 'privileges.description'.tr(),
      confirmLabel: 'crud.save'.tr(),
      cancelLabel: 'crud.cancel'.tr(),
      initialValue: current?.description ?? '',
      fieldKey: const Key('privilege-description-field'),
      confirmKey: const Key('privilege-save-button'),
    );

    if (description != null) {
      bloc.add(PrivilegeSaved(id: current?.id, description: description));
    }
  }

  Future<void> _confirmDelete(BuildContext context, PrivilegeEntity item) async {
    final bloc = context.read<PrivilegeBloc>();
    final confirmed = await showVgrConfirm(
      context,
      title: 'crud.confirmDeleteTitle'.tr(),
      message: 'crud.confirmDeleteMessage'.tr(),
      confirmLabel: 'crud.delete'.tr(),
      cancelLabel: 'crud.cancel'.tr(),
      destructive: true,
      confirmKey: const Key('privilege-confirm-delete-button'),
    );
    if (confirmed) bloc.add(PrivilegeDeleted(item.id));
  }

  @override
  Widget build(BuildContext context) {
    final canInsert = SessionAccess.instance.can('privileges', Privileges.insert);
    final canUpdate = SessionAccess.instance.can('privileges', Privileges.update);
    final canDelete = SessionAccess.instance.can('privileges', Privileges.delete);

    return VgrScaffold(
      title: 'privileges.title'.tr(),
      padded: false,
      floatingAction: !canInsert
          ? null
          : VgrFloatingAddButton(
              key: const Key('privilege-new-button'),
              onPressed: () => _openForm(context),
              tooltip: 'crud.new'.tr(),
            ),
      body: BlocConsumer<PrivilegeBloc, PrivilegeState>(
        listenWhen: (_, next) => next is PrivilegeLoaded && next.actionError != null,
        listener: (context, state) {
          // Translated by catalog code (decisions 80/83).
          showVgrMessage(context, failureText((state as PrivilegeLoaded).actionError!));
        },
        builder: (context, state) {
          return switch (state) {
            PrivilegeLoading() => const VgrLoading(),
            PrivilegeError(:final message) => VgrCenter(child: VgrText.error(message)),
            PrivilegeLoaded(:final items) => VgrListView(
                children: [
                  for (final item in items)
                    VgrListTile(
                      key: Key('privilege-${item.id}'),
                      title: trCatalog(
                        prefix: 'menu.privileges',
                        key: item.description,
                        fallback: item.description,
                      ),
                      subtitle: item.description,
                      onTap: !canUpdate ? null : () => _openForm(context, current: item),
                      trailing: !canDelete
                          ? null
                          : VgrIconButton(
                              key: Key('privilege-delete-${item.id}'),
                              icon: VgrIconName.delete,
                              tooltip: 'crud.delete'.tr(),
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
