import 'package:flutter/material.dart';

/// Encapsulates [AlertDialog] and [SnackBar] (decision 133) — the two ways
/// the system talks back to the user.

/// Confirmation dialog. Returns true only on explicit confirmation:
/// dismissing by tapping outside is a "no", which matters because most
/// callers are destructive actions.
Future<bool> showVgrConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
  Key? confirmKey,
  Key? cancelKey,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          key: cancelKey,
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel),
        ),
        ElevatedButton(
          key: confirmKey,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: destructive
              ? ElevatedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Single-field prompt — the shape every CRUD screen in the panel needed
/// and each was hand-rolling. Returns null when cancelled or left empty.
Future<String?> showVgrTextPrompt(
  BuildContext context, {
  required String title,
  required String label,
  required String confirmLabel,
  required String cancelLabel,
  String initialValue = '',
  Key? fieldKey,
  Key? confirmKey,
}) async {
  final controller = TextEditingController(text: initialValue);
  final value = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        key: fieldKey,
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(cancelLabel),
        ),
        ElevatedButton(
          key: confirmKey,
          onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return (value == null || value.isEmpty) ? null : value;
}

/// Form dialog: arbitrary content plus the standard confirm/cancel pair.
/// Returns true on confirm, null on cancel or dismissal — so callers read
/// "did the user commit?" without inventing their own convention.
Future<bool?> showVgrDialog<T>(
  BuildContext context, {
  required String title,
  required Widget content,
  required String confirmLabel,
  required String cancelLabel,
  Key? confirmKey,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: content,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel),
        ),
        ElevatedButton(
          key: confirmKey,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

/// Transient message. Screens never build a SnackBar themselves — that is
/// how duration and placement stay consistent.
void showVgrMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
