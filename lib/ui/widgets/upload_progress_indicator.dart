import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../providers/upload_provider.dart';
import '../../services/upload_service.dart';

/// Shows upload progress for [mediaId] with optional pause/resume/cancel
/// controls. Pause/resume/cancel only affect an upload that's actually in
/// flight (past the offline queue) — see [UploadService] for details.
class UploadProgressIndicator extends ConsumerStatefulWidget {
  const UploadProgressIndicator({
    super.key,
    required this.mediaId,
    this.onComplete,
    this.onCancelled,
    this.showControls = false,
  });

  final String mediaId;
  final VoidCallback? onComplete;
  final VoidCallback? onCancelled;

  /// Whether to show pause/resume/cancel buttons alongside the bar.
  final bool showControls;

  @override
  ConsumerState<UploadProgressIndicator> createState() =>
      _UploadProgressIndicatorState();
}

class _UploadProgressIndicatorState
    extends ConsumerState<UploadProgressIndicator> {
  bool _paused = false;

  @override
  Widget build(BuildContext context) {
    final notifier = ref.watch(uploadProvider);

    return StreamBuilder<UploadProgressData>(
      stream: notifier.getProgress(widget.mediaId),
      builder: (context, snapshot) {
        final progress = snapshot.data;

        if (progress != null && progress.status == 'completed') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onComplete?.call();
          });
          return const SizedBox.shrink();
        }

        if (progress != null && progress.status == 'failed') {
          return Row(
            children: [
              Icon(Icons.error_outline,
                  color: Theme.of(context).colorScheme.error, size: 16.r),
              SizedBox(width: 4.w),
              Text('Upload failed', style: TextStyle(fontSize: 12.sp)),
            ],
          );
        }

        final value = progress?.progress ?? 0.0;
        final pct = (value * 100).toStringAsFixed(0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: value),
            SizedBox(height: 4.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_paused ? 'Paused $pct%' : 'Uploading… $pct%',
                    style: TextStyle(fontSize: 12.sp)),
                if (widget.showControls)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(_paused ? Icons.play_arrow : Icons.pause,
                            size: 18.r),
                        visualDensity: VisualDensity.compact,
                        tooltip: _paused ? 'Resume' : 'Pause',
                        onPressed: () {
                          setState(() => _paused = !_paused);
                          if (_paused) {
                            notifier.pause(widget.mediaId);
                          } else {
                            notifier.resume(widget.mediaId);
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.close, size: 18.r),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Cancel',
                        onPressed: () {
                          notifier.cancel(widget.mediaId);
                          widget.onCancelled?.call();
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
