import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../../shared/register/paged_list_screen.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../../../shared/session/current_interface.dart';
import '../../domain/entity/responder_approval_entity.dart';
import '../bloc/responder_approval_bloc.dart';

/// Pending authorized-responder requests (decisions 51-52, 190: human
/// judgment, no codified rule) — a paged list without a text filter.
class ResponderApprovalQueuePage extends StatelessWidget {
  const ResponderApprovalQueuePage({super.key});

  static const screen = CurrentInterface('panic_responders');

  @override
  Widget build(BuildContext context) {
    final canResolve = screen.canUpdate;

    return PagedListScreen<ResponderApprovalEntity, ResponderApprovalBloc>(
      title: 'panicResponders.title'.tr(),
      filterable: false,
      emptyMessage: 'panicResponders.noPending'.tr(),
      rowId: (item) => item.id,
      rowBuilder: (context, item) => RegisterRow(
        title: 'panicResponders.user'.tr(args: ['${item.userId}']),
        subtitle: item.criteriaNotes ?? '',
        leadingIcon: VgrIconName.person,
        trailing: VgrRow(
          children: [
            VgrIconButton(
              key: Key('approve-${item.id}'),
              icon: VgrIconName.check,
              tooltip: 'panicResponders.approve'.tr(),
              onPressed: !canResolve
                  ? null
                  : () => context.read<ResponderApprovalBloc>().add(ResolveRequested(id: item.id, approved: true)),
            ),
            VgrIconButton(
              key: Key('deny-${item.id}'),
              icon: VgrIconName.close,
              tooltip: 'panicResponders.deny'.tr(),
              onPressed: !canResolve
                  ? null
                  : () => context.read<ResponderApprovalBloc>().add(ResolveRequested(id: item.id, approved: false)),
            ),
          ],
        ),
      ),
    );
  }
}
