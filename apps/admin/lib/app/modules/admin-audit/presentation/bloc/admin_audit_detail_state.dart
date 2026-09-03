import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entity/admin_audit_entities.dart';

sealed class AdminAuditDetailState extends Equatable {
  const AdminAuditDetailState();

  @override
  List<Object?> get props => [];
}

class AdminAuditDetailInitial extends AdminAuditDetailState {
  const AdminAuditDetailInitial();
}

class AdminAuditDetailLoading extends AdminAuditDetailState {
  const AdminAuditDetailLoading();
}

class AdminAuditDetailLoaded extends AdminAuditDetailState {
  const AdminAuditDetailLoaded(this.entry);

  final AuditEntryEntity entry;

  @override
  List<Object?> get props => [entry];
}

/// 404 when the entry does not exist, 403 without the grant, network.
class AdminAuditDetailError extends AdminAuditDetailState {
  const AdminAuditDetailError(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
