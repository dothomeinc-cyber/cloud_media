import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../providers/upload_provider.dart';
import '../../services/upload_service.dart';

class UploadProgress extends ConsumerWidget {
  const UploadProgress({
    super.key,
    required this.uploadId,
    this.showDetails = true,
  });

  final String uploadId;
  final bool showDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(uploadProvider);

    return StreamBuilder<UploadProgressData>(
      stream: notifier.getProgress(uploadId),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const SizedBox.shrink();

        final progress = snapshot.data!;

        return Container(
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(
                  value: progress.progress),
              if (showDetails) ...[
                SizedBox(height: 4.h),
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(progress.progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.sp),
                    ),
                    Text(
                      '${_fmt(progress.uploaded)} / ${_fmt(progress.total)}',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10.sp),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _fmt(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
