import 'package:flutter_riverpod/flutter_riverpod.dart';
// Bare import for types only (SyncStateType, SyncProgress, etc.) —
// the provider names collide with this file's own same-named
// declarations below, so those specific symbols are hidden here and
// reached instead through the `offline_sync` prefix.
import 'package:riverpod_offline_sync/riverpod_offline_sync.dart'
    hide
        syncStateProvider,
        syncProgressProvider,
        connectivityStatusProvider,
        isConnectedProvider,
        pendingItemsCountProvider,
        queueBreakdownProvider,
        syncMetricsProvider;
import 'package:riverpod_offline_sync/riverpod_offline_sync.dart'
    as offline_sync;

// This file previously reimplemented sync/queue/connectivity reactivity
// from scratch by calling OfflineSyncLayer.instance directly in every
// provider body. riverpod_offline_sync already ships and exports its
// own equivalent providers (offlineSyncLayerProvider, syncStateProvider,
// syncProgressProvider, pendingItemsCountProvider, queueBreakdownProvider,
// isConnectedProvider, connectivityStatusProvider, etc. — see its
// lib/src/providers/*.dart) — built on the same OfflineSyncLayer, tested
// by that package, and correctly derived from real streams rather than
// one-shot reads. CloudMedia's own providers below are now thin
// re-exports/adapters over those, kept under CloudMedia's existing
// names and shapes so nothing consuming them needs to change, but no
// longer duplicating logic the dependency already provides — including
// gaining real-time reactivity CloudMedia's own hand-rolled queue count
// never had (it was a one-shot FutureProvider that never updated after
// its first read; the package's pendingItemsCountProvider derives from
// QueueManager.queueStream and updates live on every queue mutation).

enum SyncState { idle, syncing, error }

/// Maps `riverpod_offline_sync`'s [SyncStateType] onto CloudMedia's own
/// three-value [SyncState] — kept as a standalone pure function so the
/// mapping itself is unit-testable without needing a real
/// [OfflineSyncLayer] in flight.
SyncState mapSyncStateType(SyncStateType type) {
  switch (type) {
    case SyncStateType.syncing:
      return SyncState.syncing;
    case SyncStateType.failed:
      return SyncState.error;
    case SyncStateType.idle:
    case SyncStateType.completed:
      return SyncState.idle;
  }
}

/// Watches the package's own `syncStateProvider` and maps its
/// [AsyncValue] onto CloudMedia's own three-value [SyncState] enum
/// (kept distinct from [SyncStateType] for API stability — existing
/// CloudMedia consumers already switch on this three-value enum).
///
/// A plain [Provider], not [StreamProvider] — `StreamProvider.stream`
/// was removed in Riverpod 3 (deprecated since 2.3, "either listen to
/// the provider itself (AsyncValue) or .future", per Riverpod's own
/// author). `.whenData` is the documented Riverpod 3 way to transform a
/// watched [AsyncValue]'s data while preserving its loading/error
/// states, confirmed against the actually-installed `flutter_riverpod`
/// via a real compiler error on the old `.stream`-based approach.
final syncStateProvider = Provider<AsyncValue<SyncState>>((ref) {
  return ref
      .watch(offline_sync.syncStateProvider)
      .whenData(mapSyncStateType);
});

/// Live 0.0–1.0 progress of the current push/pull sync pass (queue-level —
/// how many queued operations have been processed), distinct from
/// per-upload byte progress (see `OfflineSyncService.watchUploadProgress`
/// / `CloudMedia.watchUploadProgress` for that). Derived from the
/// package's own [SyncProgress]-typed provider; CloudMedia has
/// historically exposed this as a plain `double`, kept as-is here.
final syncProgressProvider = Provider<AsyncValue<double>>((ref) {
  return ref
      .watch(offline_sync.syncProgressProvider)
      .whenData((p) => p?.percentage ?? 0.0);
});

/// Live connectivity state — re-export of the package's own
/// [offline_sync.connectivityStatusProvider].
final connectivityStatusProvider = offline_sync.connectivityStatusProvider;

/// Live pending-operation count — re-export of the package's own
/// [offline_sync.pendingItemsCountProvider], which (unlike CloudMedia's
/// previous one-shot `FutureProvider`) updates in real time as items are
/// enqueued, processed, retried, or cleared.
final pendingMediaCountProvider = offline_sync.pendingItemsCountProvider;

/// `Provider<bool>` — read directly, never call .when() on this.
final isMediaSyncingProvider = Provider<bool>((ref) {
  return ref.watch(syncStateProvider).value == SyncState.syncing;
});

/// Live sync metrics, in CloudMedia's existing `Map<String, dynamic>`
/// shape for backward compatibility. `SyncMetrics` fields are typed, so
/// no dynamic casts are needed on the way in.
final syncMetricsProvider = Provider<Map<String, dynamic>>((ref) {
  final metrics = ref.watch(offline_sync.syncMetricsProvider);
  return {
    'successRate': metrics.successRate,
    'totalSyncs': metrics.totalSyncs,
    'failedSyncs': metrics.failedSyncs,
  };
});

/// Live pending-operations list, in CloudMedia's existing
/// `List<Map<String, dynamic>>` shape — derived from the package's own
/// real-time `pendingItemsProvider` (a `StreamProvider<List<QueueItem>>`)
/// rather than a one-shot fetch. See [syncStateProvider]'s doc comment
/// for why this watches the [AsyncValue] and `.whenData`s it rather
/// than re-deriving a raw `Stream` via the now-removed `.stream`.
final pendingOperationsProvider =
    Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  return ref.watch(offline_sync.pendingItemsProvider).whenData(
      (items) => items.map((i) => i.toJson()).toList());
});

/// Live connected/disconnected flag — re-export of the package's own
/// [offline_sync.isConnectedProvider].
final isConnectedProvider = offline_sync.isConnectedProvider;

final syncStatusTextProvider = Provider<String>((ref) {
  final state = ref.watch(syncStateProvider).value ?? SyncState.idle;
  final pending = ref.watch(pendingMediaCountProvider);
  if (state == SyncState.syncing) return 'Syncing...';
  if (state == SyncState.error) return 'Sync error';
  if (pending > 0) return '$pending pending items';
  return 'All synced';
});

/// Aggregates a list of pending-operation maps (each expected to have a
/// `category` key) into counts per category. Extracted as a standalone
/// pure function so the aggregation logic is testable without a real
/// offline queue.
Map<String, int> countOperationsByCategory(List<Map<String, dynamic>> ops) {
  final breakdown = <String, int>{};
  for (final op in ops) {
    // is String, not a direct cast — a direct `as String?` cast throws
    // for any non-null, non-String value instead of falling back to
    // 'unknown' as intended (confirmed by a real test run with a
    // non-string category value).
    final rawCat = op['category'];
    final cat = rawCat is String ? rawCat : 'unknown';
    breakdown[cat] = (breakdown[cat] ?? 0) + 1;
  }
  return breakdown;
}

/// Live per-category breakdown of pending operations, in CloudMedia's
/// existing `Map<String, int>` shape. The package's own
/// `queueBreakdownProvider` keys by `QueueItem.category` directly with
/// no transformation hook, and this one additionally guards against a
/// non-string category (see [countOperationsByCategory]), so it's built
/// from the same real-time `pendingItemsProvider` directly rather than
/// double-deriving through the package's breakdown provider. See
/// [syncStateProvider]'s doc comment for why this watches the
/// [AsyncValue] and `.whenData`s it rather than the removed `.stream`.
final queueBreakdownProvider = Provider<AsyncValue<Map<String, int>>>((ref) {
  return ref.watch(offline_sync.pendingItemsProvider).whenData(
      (items) => countOperationsByCategory(
          items.map((i) => i.toJson()).toList()));
});
