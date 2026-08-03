import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Encapsulates [TextField] (decision 133).
///
/// Every screen field goes through here, which is what makes it possible
/// to change the input look, the error presentation, or the underlying
/// widget without touching a single screen.
class VgrTextField extends StatelessWidget {
  const VgrTextField({
    super.key,
    required this.controller,
    required this.label,
    this.errorText,
    this.helperText,
    this.obscure = false,
    this.enabled = true,
    this.autofocus = false,
    this.keyboard = VgrKeyboard.text,
    this.maxLength,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final String? helperText;

  /// Passwords and any other secret — never logged, never persisted
  /// (decision 110).
  final bool obscure;
  final bool enabled;
  final bool autofocus;
  final VgrKeyboard keyboard;
  final int? maxLength;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        obscureText: obscure,
        enabled: enabled,
        autofocus: autofocus,
        keyboardType: switch (keyboard) {
          VgrKeyboard.text => TextInputType.text,
          VgrKeyboard.email => TextInputType.emailAddress,
          VgrKeyboard.number => TextInputType.number,
          VgrKeyboard.phone => TextInputType.phone,
        },
        inputFormatters:
            keyboard == VgrKeyboard.number ? [FilteringTextInputFormatter.digitsOnly] : null,
        maxLength: maxLength,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          helperText: helperText,
        ),
      );
}

enum VgrKeyboard { text, email, number, phone }

/// Encapsulates [DropdownButtonFormField] for a closed set of options.
class VgrDropdownField<T> extends StatelessWidget {
  const VgrDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final T? value;

  /// Value plus the already-translated text — the design system never
  /// translates anything itself (that belongs to the screen).
  final List<VgrOption<T>> options;
  final ValueChanged<T?>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: options
            .map((option) => DropdownMenuItem<T>(value: option.value, child: Text(option.label)))
            .toList(),
        onChanged: enabled ? onChanged : null,
      );
}

/// Encapsulates a bare [DropdownButton] — inline selection inside a list
/// row, where a full form field would not fit.
class VgrDropdown<T> extends StatelessWidget {
  const VgrDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T? value;
  final List<VgrOption<T>> options;

  /// Null disables the control — the convention every Vgr widget follows.
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) => DropdownButton<T>(
        value: value,
        items: options
            .map((option) => DropdownMenuItem<T>(value: option.value, child: Text(option.label)))
            .toList(),
        onChanged: onChanged == null
            ? null
            : (selected) {
                if (selected != null) onChanged!(selected);
              },
      );
}

class VgrOption<T> {
  const VgrOption({required this.value, required this.label});

  final T value;
  final String label;
}
