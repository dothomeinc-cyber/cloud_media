import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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

  static Future<void> show(
    BuildContext context, {
    String message = 'Loading...',
    bool showProgress = false,
    double? progress,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => LoadingDialog(
        message: message,
        showProgress: showProgress,
        progress: progress,
      ),
    );
  }

  static void hide(BuildContext context) => Navigator.pop(context);

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
      content: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showProgress && progress != null)
              SizedBox(
                width: 56.r,
                height: 56.r,
                child: CircularProgressIndicator(
                  value: progress,
                  color: cs.primary,
                ),
              )
            else
              const CupertinoActivityIndicator(radius: 16),
            SizedBox(height: 16.h),
            Text(message),
            if (showProgress && progress != null) ...[
              SizedBox(height: 8.h),
              Text('${(progress! * 100).toStringAsFixed(0)}%'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMaterial(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 60.r,
            height: 60.r,
            child: showProgress && progress != null
                ? CircularProgressIndicator(value: progress)
                : const CircularProgressIndicator(),
          ),
          SizedBox(height: 16.h),
          Text(message, style: TextStyle(fontSize: 14.sp)),
          if (showProgress && progress != null) ...[
            SizedBox(height: 8.h),
            Text(
              '${(progress! * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 14.sp),
            ),
          ],
        ],
      ),
    );
  }
}
