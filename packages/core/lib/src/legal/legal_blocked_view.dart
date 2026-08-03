import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../error/failure.dart';

/// The Legal Gate's HTTP 451 deserves its own screen, not a generic error
/// (decision 117). The API sends `code: LEGAL_BLOCKED` with
/// `params: { capability, reason }`, and the typed reason (decision 78) is
/// what the user actually needs: "nobody has reviewed this yet" reads very
/// differently from "the law here forbids it".
class LegalBlockedView extends StatelessWidget {
  const LegalBlockedView({super.key, required this.failure, this.onRetry});

  final Failure failure;
  final VoidCallback? onRetry;

  /// True when this failure is a Legal Gate refusal rather than a plain error.
  static bool matches(Failure failure) => failure.code == 'LEGAL_BLOCKED';

  @override
  Widget build(BuildContext context) {
    final reason = failure.params?['reason'] ?? 'unreviewed';
    final capability = failure.params?['capability'] ?? '';
    final reasonKey = 'legal.reasons.$reason';
    final reasonText = reasonKey.tr();

    return VgrPadding(
      all: 24,
      child: VgrColumn(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const VgrIcon(VgrIconName.legal, size: 48),
          const VgrGap.md(),
          VgrText.title(
            'legal.blockedTitle'.tr(),
            key: const Key('legal-blocked-title'),
            align: TextAlign.center,
          ),
          const VgrGap.sm(),
          VgrText(
            // Falls back to the generic sentence if the reason is one the
            // app does not know yet — new reasons must never render a key.
            reasonText == reasonKey ? 'legal.blockedGeneric'.tr() : reasonText,
            key: const Key('legal-blocked-reason'),
            align: TextAlign.center,
          ),
          if (capability.isNotEmpty) ...[
            const VgrGap.sm(),
            VgrText.caption(capability, key: const Key('legal-blocked-capability')),
          ],
          if (onRetry != null) ...[
            const VgrGap.lg(),
            VgrSecondaryButton(
              key: const Key('legal-blocked-retry'),
              label: 'legal.retry'.tr(),
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}
