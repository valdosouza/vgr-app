import 'package:equatable/equatable.dart';

sealed class AdminAuditDetailEvent extends Equatable {
  const AdminAuditDetailEvent();

  @override
  List<Object?> get props => [];
}

class AdminAuditDetailRequested extends AdminAuditDetailEvent {
  const AdminAuditDetailRequested(this.id);

  final int id;

  @override
  List<Object?> get props => [id];
}
