import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ConfirmationDialog extends StatelessWidget {
  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onConfirm,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.confirmColor,
  });

  final String title;
  final String message;
  final VoidCallback onConfirm;
  final String confirmText;
  final String cancelText;
  final Color? confirmColor;

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color? confirmColor,
    VoidCallback? onConfirm,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => ConfirmationDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        confirmColor: confirmColor,
        onConfirm: onConfirm ?? () {},
      ),
    );
  }

  bool _isCupertino(BuildContext context) {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
  }

  @override
  Widget build(BuildContext context) {
    if (_isCupertino(context)) return _buildCupertino(context);
    return _buildMaterial(context);
  }

  Widget _buildCupertino(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final actionColor = confirmColor ?? cs.primary;

    return CupertinoAlertDialog(
      title: Text(title),
      content: Padding(
        padding: EdgeInsets.only(top: 8.h),
        child: Text(message),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            cancelText,
            style: TextStyle(color: cs.onSurface),
          ),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () {
            onConfirm();
            Navigator.pop(context, true);
          },
          child: Text(
            confirmText,
            style: TextStyle(
              color: actionColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMaterial(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final actionColor = confirmColor ?? cs.primary;

    return AlertDialog(
      title: Text(title, style: TextStyle(fontSize: 18.sp)),
      content: Text(message, style: TextStyle(fontSize: 14.sp)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelText, style: TextStyle(fontSize: 14.sp)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: actionColor,
            foregroundColor: cs.onPrimary,
          ),
          onPressed: () {
            onConfirm();
            Navigator.pop(context, true);
          },
          child: Text(confirmText, style: TextStyle(fontSize: 14.sp)),
        ),
      ],
    );
  }
}
