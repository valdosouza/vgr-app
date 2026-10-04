import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/register/paged_list_bloc.dart';
import '../../../../shared/register/register_event.dart';
import '../../../../shared/register/register_state.dart';
import '../../domain/entity/legal_policy_entities.dart';
import '../../domain/repository/legal_policy_repository.dart';

export '../../../../shared/register/register_event.dart';
export '../../../../shared/register/register_state.dart';

/// Picks the jurisdiction the overview is about — back to page 1.
class CapabilitiesJurisdictionChosen extends RegisterEvent {
  const CapabilitiesJurisdictionChosen(this.jurisdiction);

  final String jurisdiction;

  @override
  List<Object?> get props => [jurisdiction];
}

/// Capability overview of ONE jurisdiction (decision 103), paged and
/// filtered (decision 220). Nothing is fetched before a jurisdiction is
/// chosen: the list starts empty and the page says what is missing.
class CapabilitiesBloc extends PagedListBloc<CapabilityOverviewEntity> {
  CapabilitiesBloc(this._repository)
      : super(
          initialState: const RegisterListLoaded<CapabilityOverviewEntity>(
            PagedQuery(),
            PagedResult.empty(),
          ),
        ) {
    on<CapabilitiesJurisdictionChosen>(_onChosen);
  }

  final LegalPolicyRepository _repository;
  String? _jurisdiction;

  /// The jurisdiction on screen; null until one is chosen.
  String? get jurisdiction => _jurisdiction;

  Future<void> _onChosen(
    CapabilitiesJurisdictionChosen event,
    Emitter<RegisterState<CapabilityOverviewEntity>> emit,
  ) {
    _jurisdiction = event.jurisdiction;
    return restart(emit);
  }

  @override
  Future<Either<Failure, PagedResult<CapabilityOverviewEntity>>> fetch(PagedQuery query) async {
    final jurisdiction = _jurisdiction;
    if (jurisdiction == null) return Right(PagedResult.empty(pageSize: query.pageSize));
    return _repository.listCapabilities(jurisdiction, query);
  }
}
