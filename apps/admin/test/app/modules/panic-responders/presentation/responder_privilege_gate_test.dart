import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_widgets/vgr_widgets.dart';
import 'package:vgr_admin/app/modules/panic-responders/domain/entity/responder_approval_entity.dart';
import 'package:vgr_admin/app/modules/panic-responders/domain/repository/responder_approval_repository.dart';
import 'package:vgr_admin/app/modules/panic-responders/presentation/bloc/responder_approval_bloc.dart';
import 'package:vgr_admin/app/modules/panic-responders/presentation/bloc/responder_approval_event.dart';
import 'package:vgr_admin/app/modules/panic-responders/presentation/page/responder_approval_queue_page.dart';

import '../../../../helpers/pump_localized.dart';
import '../../../../helpers/session_access.dart';

class MockResponderApprovalRepository extends Mock implements ResponderApprovalRepository {}

void main() {
  testWidgets('without the UPDATE grant the Approve/Deny buttons render disabled (can() wired — decision 71)', (tester) async {
    final repository = MockResponderApprovalRepository();
    when(() => repository.listPending()).thenAnswer(
      (_) async => const Right([
        ResponderApprovalEntity(id: 1, userId: 42, status: ResponderApprovalStatus.pending, criteriaNotes: null),
      ]),
    );

    revokeAllPrivileges();
    await pumpLocalized(
      tester,
      BlocProvider(
        create: (_) => ResponderApprovalBloc(repository)..add(const FetchRequested()),
        child: const ResponderApprovalQueuePage(),
      ),
    );

    // Asserts on the house widget, not on Flutter's IconButton — with the
    // design system in place (decision 133) the screen's contract is Vgr*,
    // and a test reaching past it would break on every implementation swap.
    final approve = tester.widget<VgrIconButton>(find.byKey(const Key('approve-1')));
    final deny = tester.widget<VgrIconButton>(find.byKey(const Key('deny-1')));
    expect(approve.onPressed, isNull);
    expect(deny.onPressed, isNull);
  });
}
