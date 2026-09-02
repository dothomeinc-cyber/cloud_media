import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../providers/sync_providers.dart';

/// Drop-in overlay that shows current upload/sync progress automatically.
///
/// Place this anywhere in your widget tree — typically wrapping your Scaffold
/// or inside a Stack above your main content. It is invisible when nothing
/// is uploading.
///
/// ```dart
/// // Wrap a screen:
/// Stack(
///   children: [
///     YourScreen(),
///     CloudMediaUploadOverlay(),
///   ],
/// )
///
/// // Or use the convenience builder:
/// CloudMediaUploadOverlay.wrap(child: YourScreen())
/// ```
class CloudMediaUploadOverlay extends ConsumerWidget {
  const CloudMediaUploadOverlay({
    super.key,
    this.position = OverlayPosition.bottomRight,
  });

  final OverlayPosition position;

  /// Convenience method — wraps [child] in a Stack with the overlay on top.
  static Widget wrap({
    required Widget child,
    OverlayPosition position = OverlayPosition.bottomRight,
  }) {
    return Stack(
      children: [
        child,
        CloudMediaUploadOverlay(position: position),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSyncing = ref.watch(isMediaSyncingProvider);
    final progress = ref.watch(syncProgressProvider).value ?? 0.0;
    // pendingMediaCountProvider is a plain Provider<int> (re-exported
    // from riverpod_offline_sync's own pendingItemsCountProvider) — no
    // AsyncValue unwrapping needed, unlike the FutureProvider<int> this
    // used to be.
    final pending = ref.watch(pendingMediaCountProvider);
    final isOffline = !(ref.watch(connectivityStatusProvider).value ?? true);

    // Invisible when nothing is happening
    if (!isSyncing && pending == 0 && !isOffline) {
      return const SizedBox.shrink();
    }

    final statusText = ref.watch(syncStatusTextProvider);

    Widget badge = _UploadBadge(
      isSyncing: isSyncing,
      progress: progress,
      pendingCount: pending,
      isOffline: isOffline,
      statusText: statusText,
    );

    return Positioned(
      bottom: position == OverlayPosition.bottomRight ||
              position == OverlayPosition.bottomLeft
          ? 24.h
          : null,
      top: position == OverlayPosition.topRight ||
              position == OverlayPosition.topLeft
          ? 24.h
          : null,
      right: position == OverlayPosition.bottomRight ||
              position == OverlayPosition.topRight
          ? 16.w
          : null,
      left: position == OverlayPosition.bottomLeft ||
              position == OverlayPosition.topLeft
          ? 16.w
          : null,
      child: badge,
    );
  }
}

enum OverlayPosition { bottomRight, bottomLeft, topRight, topLeft }

class _UploadBadge extends StatelessWidget {
  const _UploadBadge({
    required this.isSyncing,
    required this.progress,
    required this.pendingCount,
    required this.isOffline,
    required this.statusText,
  });

  final bool isSyncing;
  final double progress;
  final int pendingCount;
  final bool isOffline;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    final color = isOffline
        ? Colors.orange
        : isSyncing
            ? Colors.black
            : Colors.grey.shade700;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxWidth: 220.w),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isOffline)
                  Icon(Icons.wifi_off, size: 14.sp, color: Colors.white)
                else if (isSyncing)
                  SizedBox(
                    width: 14.w,
                    height: 14.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(Icons.cloud_queue, size: 14.sp, color: Colors.white),
                SizedBox(width: 6.w),
                Flexible(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (pendingCount > 0) ...[
                  SizedBox(width: 6.w),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Text(
                      '$pendingCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (isSyncing && progress > 0) ...[
              SizedBox(height: 6.h),
              LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
                minHeight: 2,
                borderRadius: BorderRadius.circular(1.r),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
