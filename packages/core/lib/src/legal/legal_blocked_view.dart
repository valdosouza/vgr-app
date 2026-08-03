import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

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

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.gavel, size: 48),
          const SizedBox(height: 16),
          Text(
            'legal.blockedTitle'.tr(),
            key: const Key('legal-blocked-title'),
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            // Falls back to the generic sentence if the reason is one the
            // app does not know yet — new reasons must never render a key.
            reasonText == reasonKey ? 'legal.blockedGeneric'.tr() : reasonText,
            key: const Key('legal-blocked-reason'),
            textAlign: TextAlign.center,
          ),
          if (capability.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              capability,
              key: const Key('legal-blocked-capability'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 24),
            OutlinedButton(
              key: const Key('legal-blocked-retry'),
              onPressed: onRetry,
              child: Text('legal.retry'.tr()),
            ),
          ],
        ],
      ),
    );
  }
}
