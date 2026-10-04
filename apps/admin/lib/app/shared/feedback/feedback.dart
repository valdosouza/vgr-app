import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

/// The ONE way a panel screen talks back to the user (decision 221 —
/// setes' `shared/feedback`). Screens call these four and never a
/// `showVgr*` dialog or a snack bar directly; `feedback_bridge_guard_test`
/// enforces it the way the design-system guard enforces decision 133.
///
/// The point is that SEVERITY is decided here, from the [Failure], never
/// by each screen: the same 409 used to be a snack bar on one screen and a
/// red line on another.

/// The answer of [askDecision].
enum Decision { yes, no, cancel }

const decisionYesKey = Key('decision-yes');
const decisionNoKey = Key('decision-no');
const decisionCancelKey = Key('decision-cancel');
const feedbackCloseKey = Key('feedback-close');

/// A completed action ("Record saved"): transient, nothing to acknowledge.
void showSuccessFeedback(BuildContext context, String message) {
  showVgrMessage(context, message);
}

/// A failed action, translated by code (decisions 80/83):
/// - **technical** — no HTTP status (the request never got an answer) or
///   5xx: a dialog the user must acknowledge, because nothing they did
///   caused it and nothing they change will fix it;
/// - **anything else** (4xx: duplicate, in use, self-lockout, forbidden…):
///   a transient message — the screen stays as it was, ready to retry.
///
/// Field errors of a form are NOT handled here: the register form anchors
/// them on their fields first and only hands over what it cannot place.
Future<void> showFailureFeedback(BuildContext context, Failure failure) async {
  if (isTechnicalFailure(failure)) {
    return showVgrAlert(
      context,
      title: 'feedback.technicalTitle'.tr(),
      message: failureText(failure),
      closeLabel: 'feedback.ok'.tr(),
      closeKey: feedbackCloseKey,
    );
  }
  showVgrMessage(context, failureText(failure));
}

/// The one validation pendency of a form (setes rule: a dialog on the
/// FIRST pendency, never the whole form painted red). Completes when the
/// user closes it, so the caller can then focus the field.
Future<void> showValidationFeedback(BuildContext context, String message) {
  return showVgrAlert(
    context,
    title: 'feedback.validationTitle'.tr(),
    message: message,
    closeLabel: 'feedback.ok'.tr(),
    closeKey: feedbackCloseKey,
  );
}

/// A typed question — yes / no, plus cancel when [withCancel] ("save the
/// changes before leaving?"). Dismissing the dialog is the most cautious
/// answer: cancel when offered, otherwise no. Every deletion asks this
/// first (with [destructive]).
Future<Decision> askDecision(
  BuildContext context, {
  required String title,
  required String message,
  String? yesLabel,
  String? noLabel,
  bool withCancel = false,
  bool destructive = false,
}) async {
  final answer = await showVgrChoice<Decision>(
    context,
    title: title,
    message: message,
    choices: [
      if (withCancel)
        VgrChoice(value: Decision.cancel, label: 'feedback.cancel'.tr(), key: decisionCancelKey),
      VgrChoice(value: Decision.no, label: noLabel ?? 'feedback.no'.tr(), key: decisionNoKey),
      VgrChoice(
        value: Decision.yes,
        label: yesLabel ?? 'feedback.yes'.tr(),
        primary: true,
        destructive: destructive,
        key: decisionYesKey,
      ),
    ],
  );
  return answer ?? (withCancel ? Decision.cancel : Decision.no);
}

/// No status (never answered) or a server-side error.
bool isTechnicalFailure(Failure failure) {
  final status = failure.statusCode;
  return status == null || status >= 500;
}
