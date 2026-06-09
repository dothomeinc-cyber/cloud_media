import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../providers/sync_providers.dart';

class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({
    super.key,
    this.showAsFloatingAction = false,
    this.showLabel = true,
  });

  final bool showAsFloatingAction;
  final bool showLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync =
        ref.watch(pendingMediaCountProvider);
    final isSyncing = ref.watch(isMediaSyncingProvider);
    final syncText = ref.watch(syncStatusTextProvider);

    return pendingAsync.when(
      data: (pendingCount) {
        if (!isSyncing && pendingCount == 0) {
          return const SizedBox.shrink();
        }

        final badge = Container(
          padding: EdgeInsets.symmetric(
              horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: isSyncing ? Colors.blue : Colors.orange,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSyncing)
                SizedBox(
                  width: 16.r,
                  height: 16.r,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(
                            Colors.white),
                  ),
                )
              else
                Icon(Icons.sync_problem,
                    color: Colors.white, size: 16.r),
              if (showLabel) ...[
                SizedBox(width: 8.w),
                Text(
                  syncText,
                  style: TextStyle(
                      color: Colors.white, fontSize: 12.sp),
                ),
              ],
              if (pendingCount > 0 && !showLabel) ...[
                SizedBox(width: 4.w),
                Container(
                  padding: EdgeInsets.all(2.r),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: BoxConstraints(
                      minWidth: 16.r, minHeight: 16.r),
                  child: Text(
                    '$pendingCount',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.sp),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        );

        if (showAsFloatingAction) {
          return Positioned(
            bottom: 16.h,
            right: 16.w,
            child: Material(
                color: Colors.transparent, child: badge),
          );
        }

        return badge;
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
