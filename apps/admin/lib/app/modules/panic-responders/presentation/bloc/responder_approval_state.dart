import 'package:equatable/equatable.dart';

import '../../domain/entity/responder_approval_entity.dart';

sealed class ResponderApprovalState extends Equatable {
  const ResponderApprovalState();

  @override
  List<Object?> get props => [];
}

class ResponderApprovalLoading extends ResponderApprovalState {
  const ResponderApprovalLoading();
}

class ResponderApprovalLoaded extends ResponderApprovalState {
  const ResponderApprovalLoaded(this.items);

  final List<ResponderApprovalEntity> items;

  @override
  List<Object?> get props => [items];
}

class ResponderApprovalError extends ResponderApprovalState {
  const ResponderApprovalError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
