import 'dart:async';
import '../api/cloud_media_api.dart';
import '../models/cloud_media_item.dart';
import '../models/cloud_media_status.dart';

/// Utility class for watching media lifecycle beyond basic [CloudMedia.watch].
///
/// Provides helpers for watching multiple items, filtering by status,
/// waiting for specific states, and tracking upload progress.
///
/// Always call [dispose] when done to cancel all subscriptions:
/// ```dart
/// final watcher = CloudMediaWatcher();
/// // ... use watcher ...
/// watcher.dispose();
/// ```
class CloudMediaWatcher {
  // watchMultiple() tracks its per-call group of subscriptions here
  // (keyed by a unique call id, since each call can involve several
  // subscriptions at once). Every other method in this class returns a
  // derived Stream without holding its own subscription open, so this
  // is the only tracking this class needs.
  final Map<String, List<StreamSubscription<CloudMediaItem>>>
      _multiSubscriptions = {};

  /// Cancel all active subscriptions and release resources.
  void dispose() {
    for (final subs in _multiSubscriptions.values) {
      for (final sub in subs) {
        sub.cancel();
      }
    }
    _multiSubscriptions.clear();
  }

  /// Watch multiple media items simultaneously.
  ///
  /// Emits the full updated list whenever any item changes. Cancels
  /// automatically when the returned stream itself is cancelled (e.g.
  /// the last listener unsubscribes) — via the broadcast controller's
  /// `onCancel`, rather than leaking a subscription per [mediaIds]
  /// entry that only [dispose] could ever clean up. Subscriptions are
  /// also tracked in [_multiSubscriptions] so a caller who calls
  /// [dispose] instead of letting the stream naturally drop its last
  /// listener is covered too.
  ///
  /// ```dart
  /// final sub = watcher.watchMultiple([id1, id2, id3]).listen((items) {
  ///   print('${items.length} items updated');
  /// });
  /// // later: sub.cancel(); — this alone is now enough to stop the
  /// // underlying per-item watches too.
  /// ```
  Stream<List<CloudMediaItem>> watchMultiple(List<String> mediaIds) {
    final current = <String, CloudMediaItem>{};
    final subs = <StreamSubscription<CloudMediaItem>>[];
    // Unique key per call so concurrent watchMultiple() calls (even for
    // overlapping mediaIds) don't collide in _multiSubscriptions.
    final callKey = 'watchMultiple:${DateTime.now().microsecondsSinceEpoch}';

    late final StreamController<List<CloudMediaItem>> controller;
    controller = StreamController<List<CloudMediaItem>>.broadcast(
      onCancel: () {
        for (final sub in subs) {
          sub.cancel();
        }
        _multiSubscriptions.remove(callKey);
      },
    );

    for (final id in mediaIds) {
      // onError forwards to the combined stream's own controller —
      // without it, an error on any single underlying watch(id) (e.g.
      // the same permission-denied-after-sign-out case documented on
      // CloudMediaProvider.watchMedia) is silently dropped by Dart's
      // default unhandled-stream-error behavior instead of ever
      // reaching whoever's listening to watchMultiple's combined stream.
      final sub = CloudMedia.watch(id).listen(
        (item) {
          current[id] = item;
          controller.add(current.values.toList());
        },
        onError: controller.addError,
      );
      subs.add(sub);
    }
    // Tracked as one entry representing all of this call's
    // subscriptions, so dispose() (which only knows about individual
    // StreamSubscriptions, not a List of them) can still reach them —
    // see dispose()'s own handling of _multiSubscriptions below.
    _multiSubscriptions[callKey] = subs;

    return controller.stream;
  }

  /// Watch a media item, only emitting when its status is in [statuses].
  ///
  /// ```dart
  /// watcher.watchWithStatusFilter(id, [
  ///   CloudMediaStatus.syncing,
  ///   CloudMediaStatus.synced,
  /// ]).listen((item) => print(item.status));
  /// ```
  Stream<CloudMediaItem> watchWithStatusFilter(
    String mediaId,
    List<CloudMediaStatus> statuses,
  ) {
    return CloudMedia.watch(mediaId)
        .where((item) => statuses.contains(item.status));
  }

  /// Wait until a media item reaches [targetStatus].
  ///
  /// Throws [TimeoutException] if the target is not reached within [timeout].
  ///
  /// ```dart
  /// final synced = await watcher.watchUntil(
  ///   item.id,
  ///   CloudMediaStatus.synced,
  ///   timeout: Duration(minutes: 2),
  /// );
  /// print(synced.downloadUrl);
  /// ```
  Future<CloudMediaItem> watchUntil(
    String mediaId,
    CloudMediaStatus targetStatus, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final completer = Completer<CloudMediaItem>();
    late StreamSubscription<CloudMediaItem> sub;
    // A Timer (not Future.delayed, which has no .cancel()) so it can be
    // stopped the moment watchUntil succeeds early — otherwise it keeps
    // running in the background for the full `timeout` duration even
    // after success, harmlessly (the isCompleted check makes it a
    // no-op) but wastefully.
    Timer? timer;

    sub = CloudMedia.watch(mediaId).listen((item) {
      if (item.status == targetStatus && !completer.isCompleted) {
        timer?.cancel();
        completer.complete(item);
        sub.cancel();
      }
    });

    timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        sub.cancel();
        completer.completeError(
            TimeoutException('watchUntil timed out after $timeout'));
      }
    });

    return completer.future;
  }

  /// Stream only the [CloudMediaStatus] for a media item.
  ///
  /// ```dart
  /// watcher.watchStatus(id).listen((status) {
  ///   print(status.displayName);
  /// });
  /// ```
  Stream<CloudMediaStatus> watchStatus(String mediaId) =>
      CloudMedia.watch(mediaId).map((item) => item.status);

  /// Stream upload progress (0.0 → 1.0) for a media item.
  ///
  /// Returns 1.0 when [CloudMediaStatus.synced].
  /// Reads `metadata['progress']` while [CloudMediaStatus.syncing].
  ///
  /// ```dart
  /// watcher.watchUploadProgress(id).listen((progress) {
  ///   print('${(progress * 100).toStringAsFixed(0)}%');
  /// });
  /// ```
  Stream<double> watchUploadProgress(String mediaId) {
    return CloudMedia.watch(mediaId).map((item) {
      if (item.status == CloudMediaStatus.synced) return 1.0;
      if (item.status == CloudMediaStatus.syncing) {
        return (item.metadata['progress'] as num?)?.toDouble() ?? 0.0;
      }
      return 0.0;
    });
  }
}
