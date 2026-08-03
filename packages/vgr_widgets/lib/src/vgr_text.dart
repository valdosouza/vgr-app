import 'package:flutter/material.dart';

/// Semantic roles a piece of text can play. Screens ask for the ROLE, never
/// for a font size — that is what lets the look change in one place.
enum VgrTextRole { headline, title, body, caption, error }

/// Encapsulates [Text] (decision 133).
///
/// Screens never build a [TextStyle]: they pick a role and the design
/// system resolves it against the current [Theme]. Swapping typography, or
/// the underlying text widget itself, touches this file only.
class VgrText extends StatelessWidget {
  const VgrText(
    this.data, {
    super.key,
    this.role = VgrTextRole.body,
    this.align,
    this.maxLines,
    this.monospace = false,
  });

  /// Shorthand for the roles used most often.
  const VgrText.headline(this.data, {super.key, this.align, this.maxLines})
      : role = VgrTextRole.headline,
        monospace = false;
  const VgrText.title(this.data, {super.key, this.align, this.maxLines})
      : role = VgrTextRole.title,
        monospace = false;
  const VgrText.caption(this.data, {super.key, this.align, this.maxLines})
      : role = VgrTextRole.caption,
        monospace = false;

  /// Error text: the color comes from the theme, so a single change keeps
  /// every failure message consistent.
  const VgrText.error(this.data, {super.key, this.align, this.maxLines})
      : role = VgrTextRole.error,
        monospace = false;

  final String data;
  final VgrTextRole role;
  final TextAlign? align;
  final int? maxLines;

  /// For content that must not be re-flowed by proportional fonts —
  /// recovery codes, secrets, identifiers.
  final bool monospace;

  TextStyle? _styleOf(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final base = switch (role) {
      VgrTextRole.headline => text.headlineSmall,
      VgrTextRole.title => text.titleMedium,
      VgrTextRole.body => text.bodyMedium,
      VgrTextRole.caption => text.bodySmall,
      VgrTextRole.error => text.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.error,
        ),
    };
    return monospace ? base?.copyWith(fontFamily: 'monospace', height: 1.6) : base;
  }

  @override
  Widget build(BuildContext context) => Text(
        data,
        style: _styleOf(context),
        textAlign: align,
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : null,
      );
}

/// Encapsulates [SelectableText] — used where the user must copy the
/// content by hand (secrets, URIs, recovery codes).
class VgrSelectableText extends StatelessWidget {
  const VgrSelectableText(
    this.data, {
    super.key,
    this.role = VgrTextRole.body,
    this.monospace = false,
  });

  final String data;
  final VgrTextRole role;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final base = switch (role) {
      VgrTextRole.headline => text.headlineSmall,
      VgrTextRole.title => text.titleMedium,
      VgrTextRole.body => text.bodyMedium,
      VgrTextRole.caption => text.bodySmall,
      VgrTextRole.error => text.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.error,
        ),
    };
    return SelectableText(
      data,
      style: monospace ? base?.copyWith(fontFamily: 'monospace', height: 1.6) : base,
    );
  }
}
