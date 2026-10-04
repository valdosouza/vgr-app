import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../../shared/register/paged_list_screen.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../domain/entity/legal_policy_entities.dart';
import '../bloc/capabilities_bloc.dart';

/// Capability catalog for ONE jurisdiction (decision 103): the verdict
/// the gate would give today — `unreviewed` rendered as the block it is
/// in a real jurisdiction (fail-closed, principle L1). Paged and filtered
/// by capability / description (decision 220) once a jurisdiction is
/// chosen in the header.
class LegalCapabilitiesPage extends StatelessWidget {
  const LegalCapabilitiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final chosen = context.select<CapabilitiesBloc, String?>((bloc) => bloc.jurisdiction);
    return PagedListScreen<CapabilityOverviewEntity, CapabilitiesBloc>(
      title: chosen == null
          ? 'legal.capabilities.title'.tr()
          : '${'legal.capabilities.title'.tr()} — $chosen',
      header: const _JurisdictionPicker(),
      emptyMessage: chosen == null ? 'legal.capabilities.hint'.tr() : null,
      rowId: (row) => row.capability,
      rowBuilder: (context, row) => RegisterRow(
        title: '${row.capability} · ${'legal.status.${row.effectiveStatus}'.tr()}',
        subtitle: row.activeRuleVersion == null
            ? row.description
            : '${row.description} · '
                '${'legal.capabilities.ruleSummary'.tr(namedArgs: {
                  'version': '${row.activeRuleVersion}',
                  'review': 'legal.review.${row.activeRuleReviewState}'.tr(),
                })}',
      ),
    );
  }
}

/// The parameter the overview cannot be fetched without.
class _JurisdictionPicker extends StatefulWidget {
  const _JurisdictionPicker();

  @override
  State<_JurisdictionPicker> createState() => _JurisdictionPickerState();
}

class _JurisdictionPickerState extends State<_JurisdictionPicker> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _load() {
    final code = _controller.text.trim().toUpperCase();
    if (code.length < 2) return;
    context.read<CapabilitiesBloc>().add(CapabilitiesJurisdictionChosen(code));
  }

  @override
  Widget build(BuildContext context) {
    return VgrRow(
      shrink: false,
      children: [
        VgrExpanded(
          child: VgrTextField(
            key: const Key('capabilities-jurisdiction-field'),
            controller: _controller,
            label: 'legal.capabilities.jurisdiction'.tr(),
            onSubmitted: (_) => _load(),
          ),
        ),
        const VgrGap.hSm(),
        VgrPrimaryButton(
          key: const Key('capabilities-load-button'),
          label: 'legal.capabilities.load'.tr(),
          onPressed: _load,
        ),
      ],
    );
  }
}
