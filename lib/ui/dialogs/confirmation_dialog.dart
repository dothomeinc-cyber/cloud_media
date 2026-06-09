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
    this.confirmColor = Colors.red,
  });

  final String title;
  final String message;
  final VoidCallback onConfirm;
  final String confirmText;
  final String cancelText;
  final Color confirmColor;

  static Future<bool?> show(BuildContext context,
      {required String title,
      required String message,
      String confirmText = 'Confirm',
      String cancelText = 'Cancel',
      Color confirmColor = Colors.red,
      VoidCallback? onConfirm}) {
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title, style: TextStyle(fontSize: 18.sp)),
      content:
          Text(message, style: TextStyle(fontSize: 14.sp)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelText,
              style: TextStyle(fontSize: 14.sp)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor),
          onPressed: () {
            onConfirm();
            Navigator.pop(context, true);
          },
          child: Text(confirmText,
              style: TextStyle(
                  color: Colors.white, fontSize: 14.sp)),
        ),
      ],
    );
  }
}
