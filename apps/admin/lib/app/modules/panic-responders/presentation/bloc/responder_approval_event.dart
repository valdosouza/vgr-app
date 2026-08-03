import 'package:equatable/equatable.dart';

sealed class ResponderApprovalEvent extends Equatable {
  const ResponderApprovalEvent();

  @override
  List<Object?> get props => [];
}

class FetchRequested extends ResponderApprovalEvent {
  const FetchRequested();
}

class ResolveRequested extends ResponderApprovalEvent {
  const ResolveRequested({required this.id, required this.approved});

  final int id;
  final bool approved;

  @override
  List<Object?> get props => [id, approved];
}
