import 'package:vgr_validators/vgr_validators.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

/// One field of a register form (setes' `RegisterField`). Declaration
/// order IS the Tab order and the order pendencies are reported in.
///
/// [name] is the API body field: a server field error (`fields[].field`,
/// decision 83) lands on the field with the same name.
sealed class RegisterField {
  const RegisterField({required this.name, required this.label, this.readOnly = false});

  final String name;

  /// Already translated.
  final String label;

  /// Shown but never edited, even when the user may save (an identifier
  /// fixed after creation, for instance).
  final bool readOnly;
}

/// A text input. [validators] run in order and stop at the first error
/// (decision 157 — they mirror the API's Zod rules, decision 154).
final class RegisterTextField extends RegisterField {
  const RegisterTextField({
    required super.name,
    required super.label,
    super.readOnly,
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
    this.initialValue = false,
  });

  final bool initialValue;
}

/// What the form hands over on save, by field name. Text comes back RAW —
/// trimming is the draft's call, because a password must not be trimmed.
class RegisterValues {
  const RegisterValues({Map<String, String> texts = const {}, Map<String, bool> flags = const {}})
      : _texts = texts,
        _flags = flags;

  final Map<String, String> _texts;
  final Map<String, bool> _flags;

  String text(String name) => _texts[name] ?? '';

  bool flag(String name) => _flags[name] ?? false;
}
