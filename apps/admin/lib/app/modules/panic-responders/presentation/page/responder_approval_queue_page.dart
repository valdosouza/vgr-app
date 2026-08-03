import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/responder_approval_bloc.dart';
import '../bloc/responder_approval_event.dart';
import '../bloc/responder_approval_state.dart';

class ResponderApprovalQueuePage extends StatelessWidget {
  const ResponderApprovalQueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('panicResponders.title'.tr())),
      body: BlocBuilder<ResponderApprovalBloc, ResponderApprovalState>(
        builder: (context, state) {
          return switch (state) {
            ResponderApprovalLoading() => const Center(child: CircularProgressIndicator()),
            ResponderApprovalError(:final message) => Center(child: Text(message)),
            ResponderApprovalLoaded(:final items) => items.isEmpty
                ? Center(child: Text('panicResponders.noPending'.tr()))
                : ListView(
                    children: [
                      for (final item in items)
                        ListTile(
                          key: Key('responder-request-${item.id}'),
                          title: Text('panicResponders.user'.tr(args: ['${item.userId}'])),
                          subtitle: Text(item.criteriaNotes ?? ''),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                key: Key('approve-${item.id}'),
                                icon: const Icon(Icons.check),
                                onPressed: !SessionAccess.instance
                                        .can('panic_responders', Privileges.update)
                                    ? null
                                    : () => context.read<ResponderApprovalBloc>().add(
                                          ResolveRequested(id: item.id, approved: true),
                                        ),
                              ),
                              IconButton(
                                key: Key('deny-${item.id}'),
                                icon: const Icon(Icons.close),
                                onPressed: !SessionAccess.instance
                                        .can('panic_responders', Privileges.update)
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
