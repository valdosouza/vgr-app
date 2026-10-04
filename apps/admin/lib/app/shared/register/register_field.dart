import 'package:vgr_validators/vgr_validators.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

/// One field of a register form (setes' `RegisterField`). Declaration
/// order IS the Tab order and the order pendencies are reported in.
///
/// [name] is the API body field: a server field error (`fields[].field`,
/// decision 83) lands on the field with the same name.
sealed class RegisterField {
  const RegisterField({
    required this.name,
    required this.label,
    this.readOnly = false,
    this.visibleWhen,
  });

  final String name;

  /// Already translated.
  final String label;

  /// Shown but never edited, even when the user may save (an identifier
  /// fixed after creation, for instance).
  final bool readOnly;

  /// Shown only while this answers true for the form's current values —
  /// a rule's reason exists only for a non-allowed status (decision 78).
  /// A hidden field is neither validated nor focused; its value still
  /// comes back, and the draft decides to drop it.
  final bool Function(RegisterValues values)? visibleWhen;
}

/// A text input. [validators] run in order and stop at the first error
/// (decision 157 — they mirror the API's Zod rules, decision 154).
final class RegisterTextField extends RegisterField {
  const RegisterTextField({
    required super.name,
    required super.label,
    super.readOnly,
    super.visibleWhen,
    this.initialValue = '',
    this.validators = const [],
    this.keyboard = VgrKeyboard.text,
    this.mask,
    this.obscure = false,
    this.hint,
    this.maxLength,
  });

  final String initialValue;
  final List<VgrValidator> validators;
  final VgrKeyboard keyboard;
  final VgrMask? mask;

  /// Secrets (passwords) — never logged, never persisted (decision 110).
  final bool obscure;

  /// Helper line under the field, already translated.
  final String? hint;
  final int? maxLength;
}

/// An on/off switch.
final class RegisterFlagField extends RegisterField {
  const RegisterFlagField({
    required super.name,
    required super.label,
    super.readOnly,
    super.visibleWhen,
    this.initialValue = false,
  });

  final bool initialValue;
}

/// One value out of a closed set (a dropdown). [required] reports an
/// empty pick as the `REQUIRED` pendency, the way Zod reports a missing
/// enum.
final class RegisterChoiceField extends RegisterField {
  const RegisterChoiceField({
    required super.name,
    required super.label,
    required this.options,
    super.readOnly,
    super.visibleWhen,
    this.initialValue,
    this.required = false,
  });

  /// Value plus its translated label.
  final List<VgrOption<String>> options;
  final String? initialValue;
  final bool required;
}

/// Several ids out of a list (checkboxes) — a screen's privileges, a menu
/// module's screens. The options usually come from a lookup that may
/// still be [loading] or have failed ([unavailableText], translated).
final class RegisterChecklistField extends RegisterField {
  const RegisterChecklistField({
    required super.name,
    required super.label,
    required this.options,
    super.readOnly,
    super.visibleWhen,
    this.initialValue = const [],
    this.ordered = false,
    this.loading = false,
    this.unavailableText,
  });

  final List<VgrOption<int>> options;
  final List<int> initialValue;

  /// The ORDER of checking matters (a menu module's screens = menu order):
  /// a checked item shows its position and the values come back in that
  /// order. Unordered selections come back sorted.
  final bool ordered;
  final bool loading;
  final String? unavailableText;
}

/// What the form hands over on save, by field name. Text comes back RAW —
/// trimming is the draft's call, because a password must not be trimmed.
class RegisterValues {
  const RegisterValues({
    Map<String, String> texts = const {},
    Map<String, bool> flags = const {},
    Map<String, String?> choices = const {},
    Map<String, List<int>> selections = const {},
  })  : _texts = texts,
        _flags = flags,
        _choices = choices,
        _selections = selections;

  final Map<String, String> _texts;
  final Map<String, bool> _flags;
  final Map<String, String?> _choices;
  final Map<String, List<int>> _selections;

  String text(String name) => _texts[name] ?? '';

  bool flag(String name) => _flags[name] ?? false;

  String? choice(String name) => _choices[name];

  List<int> selection(String name) => _selections[name] ?? const [];
}
