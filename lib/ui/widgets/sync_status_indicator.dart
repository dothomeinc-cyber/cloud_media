import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final pendingAsync = ref.watch(pendingMediaCountProvider);
    // FIX: isMediaSyncingProvider is Provider<bool> — read directly, no .when()
    final isSyncing = ref.watch(isMediaSyncingProvider);
    final syncText = ref.watch(syncStatusTextProvider);

    return pendingAsync.when(
      data: (pendingCount) {
        if (!isSyncing && pendingCount == 0) {
          return const SizedBox.shrink();
        }

        final badge = Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSyncing ? Colors.blue : Colors.orange,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSyncing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                const Icon(Icons.sync_problem,
                    color: Colors.white, size: 16),
              if (showLabel) ...[
                const SizedBox(width: 8),
                Text(syncText,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12)),
              ],
              if (pendingCount > 0 && !showLabel) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '$pendingCount',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        );

        if (showAsFloatingAction) {
          return Positioned(
            bottom: 16,
            right: 16,
            child: Material(color: Colors.transparent, child: badge),
          );
        }

        return badge;
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
