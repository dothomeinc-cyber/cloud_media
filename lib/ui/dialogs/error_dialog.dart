import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ErrorDialog extends StatelessWidget {
  const ErrorDialog({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.onDismiss,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ErrorDialog(
        title: title,
        message: message,
        onRetry: onRetry,
        onDismiss: onDismiss,
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
    return CupertinoAlertDialog(
      title: Text(title),
      content: Padding(
        padding: EdgeInsets.only(top: 8.h),
        child: Text(message),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () {
            Navigator.pop(context);
            onDismiss?.call();
          },
          child: Text(
            'Dismiss',
            style: TextStyle(color: cs.onSurface),
          ),
        ),
        if (onRetry != null)
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
              onRetry!();
            },
            child: Text(
              'Retry',
              style: TextStyle(color: cs.primary),
            ),
          ),
      ],
    );
  }

  Widget _buildMaterial(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.error, color: cs.error, size: 28.r),
          SizedBox(width: 8.w),
          Expanded(child: Text(title)),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onDismiss?.call();
          },
          child: Text('Dismiss', style: TextStyle(fontSize: 14.sp)),
        ),
        if (onRetry != null)
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onRetry!();
            },
            child: Text('Retry', style: TextStyle(fontSize: 14.sp)),
          ),
      ],
    );
  }
}
