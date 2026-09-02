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

  /// Shows the dialog and returns a [LoadingDialogHandle] that closes
  /// *this* dialog instance specifically — safer than [hide], which pops
  /// whatever happens to be on top of the navigator at the time it's
  /// called (a different dialog, bottom sheet, or route pushed after
  /// this one) rather than necessarily this dialog.
  ///
  /// ```dart
  /// final handle = LoadingDialog.showHandle(context, message: 'Uploading...');
  /// await doWork();
  /// handle.close();
  /// ```
  static LoadingDialogHandle showHandle(
    BuildContext context, {
    String message = 'Loading...',
    bool showProgress = false,
    double? progress,
  }) {
    var isClosed = false;
    final future = showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => LoadingDialog(
        message: message,
        showProgress: showProgress,
        progress: progress,
      ),
    ).whenComplete(() => isClosed = true);

    return LoadingDialogHandle._(
      close: () {
        if (isClosed) return;
        isClosed = true;
        // rootNavigator: true matches useRootNavigator above — without
        // it, Navigator.of(context) could resolve to a different,
        // nested navigator than the one showDialog actually pushed
        // onto, and pop something unrelated to this dialog instead.
        Navigator.of(context, rootNavigator: true).pop();
      },
      whenClosed: future,
    );
  }

  /// Prefer [showHandle] — this remains only for source compatibility
  /// with existing callers that don't need [hide] afterward at all
  /// (e.g. the dialog closes itself, or the caller never calls [hide]).
  static Future<void> show(
    BuildContext context, {
    String message = 'Loading...',
    bool showProgress = false,
    double? progress,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => LoadingDialog(
        message: message,
        showProgress: showProgress,
        progress: progress,
      ),
    );
  }

  /// Pops whatever is currently on top of the root navigator — this is
  /// only correct if nothing else was pushed after [show] and the
  /// dialog hasn't already been dismissed some other way. Prefer
  /// [showHandle], which closes this specific dialog instance
  /// regardless of what else is on the stack.
  static void hide(BuildContext context) =>
      Navigator.of(context, rootNavigator: true).pop();

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

/// Returned by [LoadingDialog.showHandle]. Closes that specific dialog
/// instance regardless of what else has been pushed on top of it since.
class LoadingDialogHandle {
  LoadingDialogHandle._({
    required VoidCallback close,
    required this.whenClosed,
  }) : _close = close;

  final VoidCallback _close;

  /// Completes when the dialog has actually closed — whether via
  /// [close] or any other means (e.g. the framework popping it as part
  /// of a wider navigation change).
  final Future<void> whenClosed;

  /// Closes this dialog. Safe to call more than once or after the
  /// dialog has already closed some other way — does nothing in either
  /// case rather than popping an unrelated route.
  void close() => _close();
}
