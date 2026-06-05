import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/offline_sync_service.dart';

enum SyncState { idle, syncing, error }

// Riverpod 3.x: use Notifier instead of StateProvider
class SyncStateNotifier extends Notifier<SyncState> {
  @override
  SyncState build() => SyncState.idle;
  void set(SyncState s) => state = s;
}

class SyncProgressNotifier extends Notifier<double> {
  @override
  double build() => 0.0;
  void set(double v) => state = v;
}

class ConnectivityNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void set(bool v) => state = v;
}

final syncStateProvider =
    NotifierProvider<SyncStateNotifier, SyncState>(SyncStateNotifier.new);

final syncProgressProvider =
    NotifierProvider<SyncProgressNotifier, double>(SyncProgressNotifier.new);

final connectivityStatusProvider =
    NotifierProvider<ConnectivityNotifier, bool>(ConnectivityNotifier.new);

final pendingMediaCountProvider = FutureProvider<int>((ref) async {
  return OfflineSyncService.getPendingCount();
});

/// Provider<bool> — read directly, never call .when() on this
final isMediaSyncingProvider = Provider<bool>((ref) {
  return ref.watch(syncStateProvider) == SyncState.syncing;
});

final syncMetricsProvider = Provider<Map<String, dynamic>>((ref) {
  return {'successRate': 0.95, 'totalSyncs': 0, 'failedSyncs': 0};
});

final pendingOperationsProvider =
    FutureProvider<List<dynamic>>((ref) async {
  return OfflineSyncService.getPendingOperations();
});

final isConnectedProvider =
    Provider<bool>((ref) => ref.watch(connectivityStatusProvider));

final syncStatusTextProvider = Provider<String>((ref) {
  final state = ref.watch(syncStateProvider);
  final pending = ref.watch(pendingMediaCountProvider).when(
        data: (v) => v,
        loading: () => 0,
        error: (_, __) => 0,
      );
  if (state == SyncState.syncing) return 'Syncing...';
  if (state == SyncState.error) return 'Sync error';
  if (pending > 0) return '$pending pending items';
  return 'All synced';
});

final queueBreakdownProvider =
    FutureProvider<Map<String, int>>((ref) async {
  final ops = await OfflineSyncService.getPendingOperations();
  final breakdown = <String, int>{};
  for (final op in ops) {
    final cat = (op as dynamic).category as String? ?? 'unknown';
    breakdown[cat] = (breakdown[cat] ?? 0) + 1;
  }
  return breakdown;
});
