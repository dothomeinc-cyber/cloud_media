import 'package:flutter/material.dart';

class LoadingDialog extends StatelessWidget {
  const LoadingDialog({
    super.key,
    this.message = 'Loading...',
    this.showProgress = false,
    this.progress,
  });

  final String message;
  final bool showProgress;
  final double? progress;

  static Future<void> show(BuildContext context,
      {String message = 'Loading...',
      bool showProgress = false,
      double? progress}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => LoadingDialog(
          message: message, showProgress: showProgress, progress: progress),
    );
  }

  static void hide(BuildContext context) => Navigator.pop(context);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: showProgress && progress != null
                ? CircularProgressIndicator(value: progress)
                : const CircularProgressIndicator(),
          ),
          const SizedBox(height: 16),
          Text(message),
          if (showProgress && progress != null) ...[
            const SizedBox(height: 8),
            Text('${(progress! * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 14)),
          ],
        ],
      ),
    );
  }
}
