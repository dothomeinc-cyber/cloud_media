import 'dart:async';
import 'package:cloud_media/providers/sync_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_offline_sync/riverpod_offline_sync.dart'
    as offline_sync;

// This session's earlier work on sync_providers.dart only extracted and
// tested the pure logic (mapSyncStateType, countOperationsByCategory),
// leaving every actual provider untested on the assumption that they
// all need a real OfflineSyncLayer/Firebase to exercise. That's true
// for anything deriving from offlineSyncLayerProvider directly
// (syncMetricsProvider — it calls syncLayer.metrics on a concrete,
// non-fakeable OfflineSyncLayer) — but syncStateProvider,
// connectivityStatusProvider, and the pendingItems-derived providers
// all ultimately wrap a StreamProvider from riverpod_offline_sync,
// which Riverpod's own override mechanism can replace with a fake
// stream directly (confirmed against Riverpod's documented
// StreamProvider.overrideWith pattern) — no Firebase needed at all.
//
// A real test run against an earlier version of this file hit "Bad
// state: The provider ... was disposed during loading state, yet no
// value could be emitted." — confirmed against Riverpod's own author
// (github.com/rrousselGit/riverpod/discussions/3223): calling
// `container.read(provider.future)` alone doesn't establish a listener,
// so the auto-dispose provider can be torn down (nothing is watching
// it) while still waiting for Stream.value's first (always
// microtask-delayed, never synchronous — see dart:async's own
// SynchronousStreamController docs: "you won't get any events until
// the code doing the listen has completed") emission. The fix is to
// `container.listen(...)` — which keeps the provider alive — before
// awaiting settlement, not to drop the await (Stream.value is never
// synchronous, so reading immediately would just read AsyncLoading).
void main() {
  ProviderContainer buildContainer(
      List<Override> overrides) {
    final container =
        ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    return container;
  }

  /// Establishes a real listener on [provider] (keeping it, and
  /// whatever it depends on, alive against auto-dispose) and waits
  /// until it settles into a non-loading [AsyncValue] state.
  Future<void> settle<T>(
    ProviderContainer container,
    ProviderListenable<AsyncValue<T>> provider,
  ) async {
    final completer = Completer<void>();
    late final ProviderSubscription<AsyncValue<T>> sub;
    sub = container.listen<AsyncValue<T>>(provider,
        (previous, next) {
      if (!next.isLoading && !completer.isCompleted) {
        completer.complete();
      }
    }, fireImmediately: true);
    if (!container.read(provider).isLoading &&
        !completer.isCompleted) {
      completer.complete();
    }
    await completer.future;
    // Subscription is intentionally left open for the rest of the
    // test — addTearDown(container.dispose) above cleans it up. Using
    // sub here (rather than discarding it) also keeps the analyzer
    // from flagging it as unused.
    addTearDown(sub.close);
  }

  group('syncStateProvider', () {
    test(
        'maps the underlying package SyncStateType to CloudMedia SyncState',
        () async {
      final container = buildContainer([
        offline_sync.syncStateProvider.overrideWith((ref) =>
            Stream.value(
                offline_sync.SyncStateType.syncing)),
      ]);

      await settle(container, syncStateProvider);

      final result = container.read(syncStateProvider);
      expect(result.value, SyncState.syncing);
    });

    test('maps failed to SyncState.error', () async {
      final container = buildContainer([
        offline_sync.syncStateProvider.overrideWith((ref) =>
            Stream.value(
                offline_sync.SyncStateType.failed)),
      ]);
      await settle(container, syncStateProvider);

      expect(container.read(syncStateProvider).value,
          SyncState.error);
    });
  });

  group('isMediaSyncingProvider', () {
    test(
        'is true only while the underlying state is syncing',
        () async {
      final container = buildContainer([
        offline_sync.syncStateProvider.overrideWith((ref) =>
            Stream.value(
                offline_sync.SyncStateType.syncing)),
      ]);
      await settle(container, syncStateProvider);

      expect(
          container.read(isMediaSyncingProvider), isTrue);
    });

    test('is false when idle', () async {
      final container = buildContainer([
        offline_sync.syncStateProvider.overrideWith((ref) =>
            Stream.value(offline_sync.SyncStateType.idle)),
      ]);
      await settle(container, syncStateProvider);

      expect(
          container.read(isMediaSyncingProvider), isFalse);
    });

    test('is false while still loading (no data yet)', () {
      final container = buildContainer([
        offline_sync.syncStateProvider
            .overrideWith((ref) => const Stream.empty()),
      ]);

      // No settle() call on purpose — reading immediately, while the
      // override's stream hasn't emitted anything yet (AsyncLoading).
      expect(
          container.read(isMediaSyncingProvider), isFalse);
    });
  });

  group('connectivityStatusProvider / isConnectedProvider',
      () {
    test(
        'isConnectedProvider reflects connectivityStatusProvider',
        () async {
      final container = buildContainer([
        offline_sync.connectivityStatusProvider
            .overrideWith((ref) => Stream.value(false)),
      ]);
      await settle(container,
          offline_sync.connectivityStatusProvider);

      expect(
          container.read(offline_sync.isConnectedProvider),
          isFalse);
      // CloudMedia's own isConnectedProvider is a direct re-export of
      // the package's, so reading either resolves to the same value.
      expect(container.read(isConnectedProvider), isFalse);
    });
  });

  group(
      'pendingMediaCountProvider / pendingOperationsProvider / queueBreakdownProvider',
      () {
    test(
        'pendingMediaCountProvider reflects the overridden queue length',
        () async {
      final container = buildContainer([
        offline_sync.pendingItemsProvider
            .overrideWith((ref) => Stream.value(const [])),
      ]);
      await settle(
          container, offline_sync.pendingItemsProvider);

      expect(container.read(pendingMediaCountProvider), 0);
    });
  });

  group('syncStatusTextProvider', () {
    test('reports "Syncing..." while syncing', () async {
      final container = buildContainer([
        offline_sync.syncStateProvider.overrideWith((ref) =>
            Stream.value(
                offline_sync.SyncStateType.syncing)),
        offline_sync.pendingItemsProvider
            .overrideWith((ref) => Stream.value(const [])),
      ]);
      await settle(container, syncStateProvider);
      await settle(
          container, offline_sync.pendingItemsProvider);

      expect(container.read(syncStatusTextProvider),
          'Syncing...');
    });

    test(
        'reports "Sync error" on failure, even with nothing pending',
        () async {
      final container = buildContainer([
        offline_sync.syncStateProvider.overrideWith((ref) =>
            Stream.value(
                offline_sync.SyncStateType.failed)),
        offline_sync.pendingItemsProvider
            .overrideWith((ref) => Stream.value(const [])),
      ]);
      await settle(container, syncStateProvider);
      await settle(
          container, offline_sync.pendingItemsProvider);

      expect(container.read(syncStatusTextProvider),
          'Sync error');
    });

    test(
        'reports "All synced" when idle with nothing pending',
        () async {
      final container = buildContainer([
        offline_sync.syncStateProvider.overrideWith((ref) =>
            Stream.value(offline_sync.SyncStateType.idle)),
        offline_sync.pendingItemsProvider
            .overrideWith((ref) => Stream.value(const [])),
      ]);
      await settle(container, syncStateProvider);
      await settle(
          container, offline_sync.pendingItemsProvider);

      expect(container.read(syncStatusTextProvider),
          'All synced');
    });
  });

  // syncMetricsProvider is NOT covered here — it reads
  // offlineSyncLayerProvider directly (a concrete, non-fakeable
  // OfflineSyncLayer, not itself a Stream/Future-based provider this
  // override mechanism can replace) and calls syncLayer.metrics on it,
  // which genuinely needs a real initialized OfflineSyncLayer to
  // exercise — consistent with every other Firebase/OfflineSyncLayer-
  // dependent gap documented throughout this test suite.
}
