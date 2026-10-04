import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../feedback/feedback.dart';
import 'register_field.dart';

/// The register form (setes' `RegisterFormPage`), rendered inside the
/// shell by [VgrFormShell]: back · title · delete · save over the fields.
///
/// - Tab order = declaration order; Enter moves to the next text field and
///   submits from the last one.
/// - Validation reports ONE pendency at a time: a dialog naming the first
///   field that fails, then the cursor lands on it — never the whole form
///   painted red (setes rule).
/// - [showServerFieldError] does the same for the API's `fields[]`
///   (decision 83), so a 422 the client did not foresee still points at the
///   right field.
/// - [onSave] null = read-only: the user may see the record but not
///   change it — every field is locked and there is no save.
class RegisterFormPage extends StatefulWidget {
  const RegisterFormPage({
    super.key,
    required this.title,
    required this.fields,
    required this.onBack,
    this.onSave,
    this.onDelete,
    this.busy = false,
  });

  final String title;
  final List<RegisterField> fields;
  final VoidCallback onBack;
  final ValueChanged<RegisterValues>? onSave;
  final VoidCallback? onDelete;
  final bool busy;

  @override
  State<RegisterFormPage> createState() => RegisterFormPageState();
}

class RegisterFormPageState extends State<RegisterFormPage> {
  final _controllers = <String, TextEditingController>{};
  final _focusNodes = <String, FocusNode>{};
  final _flags = <String, bool>{};

  /// The one field currently pointed at by a pendency, and its text.
  String? _pendingField;
  String? _pendingText;

  bool get _readOnly => widget.onSave == null;

  List<RegisterTextField> get _textFields =>
      widget.fields.whereType<RegisterTextField>().toList();

  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      switch (field) {
        case RegisterTextField():
          _controllers[field.name] = TextEditingController(text: field.initialValue);
          _focusNodes[field.name] = FocusNode();
        case RegisterFlagField():
          _flags[field.name] = field.initialValue;
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  RegisterValues get _values => RegisterValues(
        texts: {for (final entry in _controllers.entries) entry.key: entry.value.text},
        flags: Map.of(_flags),
      );

  Future<void> _submit() async {
    if (_readOnly || widget.busy) return;
    setState(() => _pendingField = null);

    for (final field in _textFields) {
      if (field.readOnly) continue;
      final value = _controllers[field.name]!.text;
      for (final rule in field.validators) {
        final error = rule(value);
        if (error != null) {
          await _pend(
            field.name,
            fieldFailureText(FieldFailure(
              field: field.name,
              message: error.code,
              code: error.code,
              params: error.params,
            )),
          );
          return;
        }
      }
    }
    widget.onSave!(_values);
  }

  /// Anchors the first of [failure]'s field errors that names a field of
  /// this form — the same dialog and focus as a local pendency. False when
  /// none does (no `fields[]`, or only fields the form does not show): the
  /// caller then falls back to `showFailureFeedback`.
  bool showServerFieldError(Failure failure) {
    for (final fieldError in failure.fields ?? const <FieldFailure>[]) {
      if (widget.fields.any((field) => field.name == fieldError.field)) {
        _pend(fieldError.field, fieldFailureText(fieldError));
        return true;
      }
    }
    return false;
  }

  Future<void> _pend(String name, String text) async {
    final label = widget.fields.firstWhere((field) => field.name == name).label;
    setState(() {
      _pendingField = name;
      _pendingText = text;
    });
    await showValidationFeedback(context, '$label: $text');
    if (mounted) _focusNodes[name]?.requestFocus();
  }

  void _advanceFrom(RegisterTextField field) {
    final editable = _textFields.where((f) => !f.readOnly && !_readOnly).toList();
    final index = editable.indexOf(field);
    if (index >= 0 && index < editable.length - 1) {
      _focusNodes[editable[index + 1].name]!.requestFocus();
    } else {
      _submit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return VgrFormShell(
      title: widget.title,
      onBack: widget.onBack,
      backTooltip: 'register.back'.tr(),
      onSave: _readOnly ? null : _submit,
      saveLabel: 'register.save'.tr(),
      onDelete: widget.onDelete,
      deleteTooltip: 'register.delete'.tr(),
      busy: widget.busy,
      body: VgrColumn(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final field in widget.fields)
            switch (field) {
              RegisterTextField() => VgrTextField(
                  key: Key('register-field-${field.name}'),
                  controller: _controllers[field.name]!,
                  focusNode: _focusNodes[field.name],
                  label: field.label,
                  keyboard: field.keyboard,
                  mask: field.mask,
                  obscure: field.obscure,
                  helperText: field.hint,
                  maxLength: field.maxLength,
                  readOnly: field.readOnly || _readOnly,
                  errorText: _pendingField == field.name ? _pendingText : null,
                  onSubmitted: (_) => _advanceFrom(field),
                ),
              RegisterFlagField() => VgrSwitchTile(
                  key: Key('register-field-${field.name}'),
                  label: field.label,
                  value: _flags[field.name]!,
                  onChanged: field.readOnly || _readOnly
                      ? null
                      : (value) => setState(() => _flags[field.name] = value),
                ),
            },
        ],
      ),
    );
  }
}
