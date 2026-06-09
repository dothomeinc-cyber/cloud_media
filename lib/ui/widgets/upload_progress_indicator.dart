import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../providers/upload_provider.dart';
import '../../services/storage_queue_service.dart';
import '../../services/upload_service.dart';

class UploadProgressIndicator extends ConsumerWidget {
  const UploadProgressIndicator({
    super.key,
    required this.mediaId,
    this.onComplete,
  });

  final String mediaId;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(uploadProvider);

    return StreamBuilder<UploadProgressData>(
      stream: notifier.getProgress(mediaId),
      builder: (context, snapshot) {
        final progress = snapshot.data;

        if (progress != null &&
            progress.status == 'completed') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onComplete?.call();
          });
          return const SizedBox.shrink();
        }

        final value = progress?.progress ?? 0.0;
        final pct = (value * 100).toStringAsFixed(0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: value),
            SizedBox(height: 4.h),
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Text('Uploading… $pct%',
                    style: TextStyle(fontSize: 12.sp)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.pause, size: 16.r),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Pause',
                      onPressed: () =>
                          StorageQueueService.pauseUpload(
                              mediaId),
                    ),
                    SizedBox(width: 4.w),
                    IconButton(
                      icon: Icon(Icons.play_arrow,
                          size: 16.r),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Resume',
                      onPressed: () =>
                          StorageQueueService.resumeUpload(
                              mediaId),
                    ),
                    SizedBox(width: 4.w),
                    IconButton(
                      icon: Icon(Icons.cancel, size: 16.r),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Cancel',
                      onPressed: () =>
                          StorageQueueService.cancelUpload(
                              mediaId),
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
