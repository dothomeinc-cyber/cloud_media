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
  final Map<String, StreamSubscription<CloudMediaItem>> _subscriptions = {};

  /// Cancel all active subscriptions and release resources.
  void dispose() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  /// Watch multiple media items simultaneously.
  ///
  /// Emits the full updated list whenever any item changes.
  ///
  /// ```dart
  /// watcher.watchMultiple([id1, id2, id3]).listen((items) {
  ///   print('${items.length} items updated');
  /// });
  /// ```
  Stream<List<CloudMediaItem>> watchMultiple(List<String> mediaIds) {
    final controller = StreamController<List<CloudMediaItem>>.broadcast();
    final current = <String, CloudMediaItem>{};

    for (final id in mediaIds) {
      CloudMedia.watch(id).listen((item) {
        current[id] = item;
        controller.add(current.values.toList());
      });
    }

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

    sub = CloudMedia.watch(mediaId).listen((item) {
      if (item.status == targetStatus && !completer.isCompleted) {
        completer.complete(item);
        sub.cancel();
      }
    });

    Future.delayed(timeout, () {
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
