import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CommonDialogs {
  static Future<void> showTextFieldDialog({
    required BuildContext context,
    required String title,
    required String labelText,
    required String initialValue,
    required Function(String) onSave,
    String? hintText,
    String? prefixText,
    String? helperText,
    String? saveLabel,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    bool obscureText = false,
    int? maxLength,
    TextAlign textAlign = TextAlign.start,
    TextStyle? style,
    bool autofocus = true,
  }) async {
    final controller = TextEditingController(text: initialValue);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: labelText,
                hintText: hintText,
                prefixText: prefixText,
                helperText: helperText,
              ),
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              obscureText: obscureText,
              maxLength: maxLength,
              textAlign: textAlign,
              style: style,
              autofocus: autofocus,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              onSave(controller.text);
              Navigator.pop(context);
            },
            child: Text(saveLabel ?? 'Save'),
          ),
        ],
      ),
    );
  }

  static Future<bool> showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String content,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    Color? confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelLabel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: confirmColor != null
                ? ElevatedButton.styleFrom(
                    backgroundColor: confirmColor,
                    foregroundColor: Colors.white)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
