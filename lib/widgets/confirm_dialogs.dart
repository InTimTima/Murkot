import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

Future<bool?> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  bool isDestructive = false,
}) {
  final strings = context.strings;
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(cancelLabel ?? strings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: isDestructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                )
              : null,
          child: Text(confirmLabel ?? strings.yes),
        ),
      ],
    ),
  );
}

Future<bool> showDeleteAccountDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => const _DeleteAccountDialog(),
  );
  return result ?? false;
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return AlertDialog(
      title: Text(strings.deleteAccountTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.deleteAccountMessage),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: strings.deleteAccountHint,
              ),
              validator: (value) {
                if (value?.trim() != strings.deleteAccountPhrase) {
                  return strings.deleteAccountValidation;
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, true);
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(strings.deleteAccountConfirm),
        ),
      ],
    );
  }
}

Future<String?> showTextInputDialog({
  required BuildContext context,
  required String title,
  required String hint,
  String? initialValue,
  String? Function(String?)? validator,
  bool obscureText = false,
  TextInputType keyboardType = TextInputType.text,
  int maxLines = 1,
  int? maxLength,
}) async {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => _TextInputDialog(
      title: title,
      hint: hint,
      initialValue: initialValue,
      validator: validator,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
    ),
  );
}

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.hint,
    this.initialValue,
    this.validator,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.maxLength,
  });

  final String title;
  final String hint;
  final String? initialValue;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType keyboardType;
  final int maxLines;
  final int? maxLength;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          decoration: InputDecoration(hintText: widget.hint),
          autofocus: true,
          obscureText: widget.obscureText,
          keyboardType: widget.maxLines > 1
              ? TextInputType.multiline
              : widget.keyboardType,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          maxLength: widget.maxLength,
          validator: widget.validator,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _controller.text.trim());
            }
          },
          child: Text(strings.save),
        ),
      ],
    );
  }
}

Future<bool> showPasswordConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required Future<bool> Function(String password) onConfirm,
}) async {
  final password = await showTextInputDialog(
    context: context,
    title: title,
    hint: context.strings.passwordHint,
    obscureText: true,
    validator: (v) => v == null || v.isEmpty ? context.strings.passwordRequired : null,
  );

  if (password == null || !context.mounted) return false;
  return onConfirm(password);
}
