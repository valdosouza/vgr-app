import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../bloc/responder_approval_bloc.dart';
import '../bloc/responder_approval_event.dart';
import '../bloc/responder_approval_state.dart';

class ResponderApprovalQueuePage extends StatelessWidget {
  const ResponderApprovalQueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    final canResolve = SessionAccess.instance.can('panic_responders', Privileges.update);

    return VgrScaffold(
      title: 'panicResponders.title'.tr(),
      padded: false,
      body: BlocBuilder<ResponderApprovalBloc, ResponderApprovalState>(
        builder: (context, state) {
          return switch (state) {
            ResponderApprovalLoading() => const VgrLoading(),
            ResponderApprovalError(:final message) => VgrCenter(child: VgrText.error(message)),
            ResponderApprovalLoaded(:final items) => items.isEmpty
                ? VgrCenter(child: VgrText('panicResponders.noPending'.tr()))
                : VgrListView(
                    children: [
                      for (final item in items)
                        VgrListTile(
                          key: Key('responder-request-${item.id}'),
                          title: 'panicResponders.user'.tr(args: ['${item.userId}']),
                          subtitle: item.criteriaNotes ?? '',
                          trailing: VgrRow(
                            children: [
                              VgrIconButton(
                                key: Key('approve-${item.id}'),
                                icon: VgrIconName.check,
                                tooltip: 'crud.save'.tr(),
                                onPressed: !canResolve
                                    ? null
                                    : () => context.read<ResponderApprovalBloc>().add(
                                          ResolveRequested(id: item.id, approved: true),
                                        ),
                              ),
                              VgrIconButton(
                                key: Key('deny-${item.id}'),
                                icon: VgrIconName.close,
                                tooltip: 'crud.cancel'.tr(),
                                onPressed: !canResolve
                                    ? null
                                    : () => context.read<ResponderApprovalBloc>().add(
                                          ResolveRequested(id: item.id, approved: false),
                                        ),
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
