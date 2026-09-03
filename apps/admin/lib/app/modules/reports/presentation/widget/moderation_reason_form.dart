import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:vgr_validators/vgr_validators.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../domain/entity/moderation_reason.dart';

/// The ONE reason form every moderation act goes through (B2, decisions
/// 162/163): hide, unhide, block, unblock — same catalog, same rule.
///
/// Validation mirrors `moderationReasonDto` through `VgrValidators`
/// (157): the catalog code is REQUIRED; the note is `minLength(3)` ONLY
/// when the code is `other` (the rule list is built conditionally) and
/// `maxLength(500)` always. Feedback only — the API revalidates (47/110)
/// and answers 422 by field code (83), which the page renders.
///
/// Pure Components layer: no bloc, no repository — the page decides what
/// [onSubmit] means.
class ModerationReasonForm extends StatefulWidget {
  const ModerationReasonForm({
    super.key,
    required this.title,
    required this.busy,
    required this.onSubmit,
    required this.onCancel,
  });

  final String title;
  final bool busy;

  /// `note` is `null` when left blank — the repository then omits it.
  final void Function(String reasonCode, String? note) onSubmit;
  final VoidCallback onCancel;

  @override
  State<ModerationReasonForm> createState() => _ModerationReasonFormState();
}

class _ModerationReasonFormState extends State<ModerationReasonForm> {
  final _noteController = TextEditingController();
  String? _reasonCode;
  Map<String, String> _errors = const {};

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final errors = VgrValidators.validate({
      'reasonCode': (_reasonCode ?? '', [VgrValidators.required]),
      'note': (
        _noteController.text,
        [
          // `other` → the note is mandatory and at least 3 chars (163).
          if (_reasonCode == moderationReasonOther)
            VgrValidators.minLength(moderationNoteMinLengthWhenOther),
          VgrValidators.maxLength(moderationNoteMaxLength),
        ],
      ),
    });
    setState(() => _errors = {
          for (final e in errors.entries)
            e.key: fieldFailureText(FieldFailure(
              field: e.key,
              message: e.value.code,
              code: e.value.code,
              params: e.value.params,
            )),
        });
    if (errors.isNotEmpty) return;

    final note = _noteController.text.trim();
    widget.onSubmit(_reasonCode!, note.isEmpty ? null : note);
  }

  @override
  Widget build(BuildContext context) {
    return VgrCard(
      child: VgrPadding(
        child: VgrColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VgrText.title(widget.title),
            VgrText.caption('reports.moderation.hint'.tr()),
            const VgrGap.sm(),
            VgrDropdownField<String>(
              key: const Key('moderation-reason-field'),
              label: 'reports.moderation.reasonLabel'.tr(),
              value: _reasonCode,
              options: [
                for (final code in moderationReasons)
                  VgrOption(value: code, label: 'reports.moderation.reason.$code'.tr()),
              ],
              onChanged: (v) => setState(() => _reasonCode = v),
            ),
            if (_errors['reasonCode'] != null)
              VgrText.error(_errors['reasonCode']!, key: const Key('moderation-reason-error')),
            const VgrGap.sm(),
            VgrTextField(
              key: const Key('moderation-note-field'),
              controller: _noteController,
              label: 'reports.moderation.noteLabel'.tr(),
              errorText: _errors['note'],
              maxLength: moderationNoteMaxLength,
            ),
            const VgrGap.sm(),
            VgrRow(children: [
              VgrPrimaryButton(
                key: const Key('moderation-submit-button'),
                label: 'reports.moderation.submit'.tr(),
                busy: widget.busy,
                onPressed: _submit,
              ),
              const VgrGap.hSm(),
              VgrTextButton(
                key: const Key('moderation-cancel-button'),
                label: 'reports.moderation.cancel'.tr(),
                onPressed: widget.busy ? null : widget.onCancel,
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
