import 'dart:async';
import '../api/cloud_media_api.dart';
import '../models/cloud_media_item.dart';
import '../models/cloud_media_status.dart';

class CloudMediaWatcher {
  final Map<String, StreamSubscription<CloudMediaItem>> _subscriptions = {};

  void dispose() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

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

  Stream<CloudMediaItem> watchWithStatusFilter(
    String mediaId,
    List<CloudMediaStatus> statuses,
  ) {
    return CloudMedia.watch(mediaId)
        .where((item) => statuses.contains(item.status));
  }

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

  Stream<CloudMediaStatus> watchStatus(String mediaId) =>
      CloudMedia.watch(mediaId).map((item) => item.status);

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
