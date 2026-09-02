import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:riverpod_offline_sync/riverpod_offline_sync.dart';
import '../constants/firestore_paths.dart';
import '../utils/error_handler.dart';
import '../utils/logger.dart';

/// A single upload's progress, in bytes and as a 0.0–1.0 fraction.
class MediaUploadProgress {
  const MediaUploadProgress({
    required this.mediaId,
    required this.fraction,
    required this.bytesTransferred,
    required this.totalBytes,
    this.isComplete = false,
    this.isFailed = false,
  });

  final String mediaId;
  final double fraction;
  final int bytesTransferred;
  final int totalBytes;
  final bool isComplete;
  final bool isFailed;
}

enum QueuePriority { critical, high, normal, low, background }

/// Whether an upload-progress write to Firestore's `metadata.progress`
/// is worth making right now, given the last fraction actually written.
///
/// Extracted as a standalone pure function (rather than inlined in the
/// upload handler) specifically so the throttling threshold itself is
/// unit-testable without needing a real upload/Firebase in flight —
/// the handler that calls this still does, since it also has to
/// perform the actual write.
bool shouldPersistProgress({
  required double fraction,
  required double lastWritten,
  double threshold = 0.05,
}) {
  return fraction - lastWritten >= threshold;
}

extension QueuePriorityValue on QueuePriority {
  int get value {
    switch (this) {
      case QueuePriority.critical:   return 0;
      case QueuePriority.high:       return 1;
      case QueuePriority.normal:     return 2;
      case QueuePriority.low:        return 3;
      case QueuePriority.background: return 4;
    }
  }
}

/// Wraps `riverpod_offline_sync` for CloudMedia's Firebase work.
///
/// Two upload paths are used deliberately:
///
/// - **File bytes (`media_upload`, `thumbnail_upload`)** go through
///   [StorageQueue] directly, *not* just the generic operation queue.
///   Only [StorageQueue] gives per-upload progress plus pause/resume/
///   cancel on the underlying Firebase `UploadTask` — the generic
///   `registerOperationHandler` queue is fire-and-forget with no
///   lifecycle hooks into an in-flight upload. Offline durability for
///   these still comes from `OfflineSyncLayer`: each call is itself
///   wrapped in `submitOperation`, so a not-yet-attempted upload is
///   queued and retried like any other operation on reconnect; once it
///   *starts* uploading, [StorageQueue] takes over progress/pause/
///   resume/cancel for that attempt.
/// - **Firestore metadata writes (`media_metadata_create`,
///   `media_delete`)** go through the plain operation queue, since a
///   small document write has no comparable pause/resume/cancel need.

/// The subset of [StorageQueue]'s pause/resume/cancel/status API that
/// [OfflineSyncService] depends on for those four operations. Exists so
/// tests can swap in a fake implementation that never touches Firebase
/// at all — [StorageQueue] itself is a concrete class with a
/// constructor that eagerly evaluates `FirebaseStorage.instance` even
/// for pause/resume/cancel/status calls, which never actually need
/// Firebase Storage (confirmed against `StorageQueue`'s own source:
/// none of these four touch its `_storage` field). Upload/delete still
/// go through the real [StorageQueue] directly — this interface
/// intentionally doesn't cover them, since faking real file uploads
/// isn't the goal here.
abstract class UploadControl {
  void pauseUpload(String idempotencyKey);
  void resumeUpload(String idempotencyKey);
  void cancelUpload(String idempotencyKey);
  bool isUploading(String idempotencyKey);
  bool isCancelled(String idempotencyKey);
}

/// Wraps a real [StorageQueue] to satisfy [UploadControl]. This is what
/// [OfflineSyncService] uses by default in real app code.
class _RealUploadControl implements UploadControl {
  _RealUploadControl(this._queue);
  final StorageQueue _queue;

  @override
  void pauseUpload(String idempotencyKey) => _queue.pauseUpload(idempotencyKey);
  @override
  void resumeUpload(String idempotencyKey) => _queue.resumeUpload(idempotencyKey);
  @override
  void cancelUpload(String idempotencyKey) => _queue.cancelUpload(idempotencyKey);
  @override
  bool isUploading(String idempotencyKey) => _queue.isUploading(idempotencyKey);
  @override
  bool isCancelled(String idempotencyKey) => _queue.isCancelled(idempotencyKey);
}

class OfflineSyncService {
  OfflineSyncService._();
  static bool _initialized = false;
  static final StorageQueue _storageQueue = StorageQueue();

  /// Per-upload timeout, applied to each `StorageQueue.uploadFile` call.
  /// Set from `CloudMediaConfig.uploadTimeout` by
  /// `CloudMediaProvider.initialize()` — previously that config field
  /// was fully modeled (constructor, copyWith, toJson) but never
  /// actually read anywhere, so a configured timeout silently did
  /// nothing. Defaults to 5 minutes, matching `CloudMediaConfig`'s own
  /// default, so this is still sensible even for a caller that only
  /// ever uses `OfflineSyncService` directly without going through
  /// `CloudMediaProvider` at all.
  static Duration uploadTimeout = const Duration(minutes: 5);

  // Not eagerly wrapped around _storageQueue at the field-initializer
  // level — doing so would force _storageQueue's own (Firebase-
  // touching) construction the moment _uploadControl is first read,
  // even for a test that only wants to override upload control and
  // never touches real uploads. Null until either read (lazily wraps
  // the real _storageQueue then) or explicitly overridden for tests.
  static UploadControl? _uploadControlOverride;
  static UploadControl get _uploadControl =>
      _uploadControlOverride ?? _RealUploadControl(_storageQueue);

  /// Test-only seam: swap in a fake [UploadControl] (e.g. a plain
  /// in-memory implementation with no Firebase dependency at all) for
  /// [pauseUpload]/[resumeUpload]/[cancelUpload]/[isUploading]/
  /// [isCancelled]. Real app code never calls this. Does NOT affect
  /// actual uploads/deletes ([uploadMedia], [deleteMedia], etc.), which
  /// always go through the real [StorageQueue] — see [UploadControl]'s
  /// doc comment for why that split exists.
  @visibleForTesting
  static void debugOverrideUploadControl(UploadControl control) {
    _uploadControlOverride = control;
  }

  // Per-mediaId broadcast progress. StorageQueue only reports a fractional
  // 0.0–1.0 progress via its onProgress callback (it doesn't expose the
  // raw bytesTransferred/totalBytes from the underlying TaskSnapshot to
  // callers), so bytesTransferred here is derived as
  // fraction * totalBytes, using the file's own on-disk size as
  // totalBytes — the same number the fraction was computed from on the
  // Storage side, since File.putFile uploads the whole file.
  static final Map<String, StreamController<MediaUploadProgress>>
      _progressControllers = {};

  /// Live progress for [mediaId]'s upload. The stream closes itself after
  /// emitting a final `isComplete`/`isFailed` event, or — if every
  /// listener unsubscribes first, before the upload reaches either
  /// state (e.g. the widget watching it is disposed, or the app never
  /// gets far enough to complete/fail the upload) — via `onCancel`, so
  /// this doesn't leak an entry in [_progressControllers] forever for
  /// an upload nobody is watching anymore. If something re-subscribes
  /// to [mediaId] later, a fresh controller is created; any progress
  /// emitted while nobody was listening is simply not replayed (this is
  /// a live/broadcast stream, not a replay one — matching its behavior
  /// before this fix for a listener that was present throughout).
  static Stream<MediaUploadProgress> watchUploadProgress(String mediaId) {
    if (_progressControllers.containsKey(mediaId)) {
      return _progressControllers[mediaId]!.stream;
    }
    late final StreamController<MediaUploadProgress> controller;
    controller = StreamController.broadcast(
      onCancel: () {
        if (_progressControllers[mediaId] == controller) {
          _progressControllers.remove(mediaId);
        }
      },
    );
    _progressControllers[mediaId] = controller;
    return controller.stream;
  }

  static void _emitProgress(String mediaId, MediaUploadProgress progress) {
    final controller = _progressControllers[mediaId];
    if (controller == null || controller.isClosed) return;
    controller.add(progress);
    if (progress.isComplete || progress.isFailed) {
      // Let the final event flush to listeners before tearing down.
      scheduleMicrotask(() {
        controller.close();
        _progressControllers.remove(mediaId);
      });
    }
  }

  static Future<void> initialize() async {
    if (_initialized) return;
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    await OfflineSyncLayer.instance.initialize(
      config: const SyncConfig(
        autoSyncOnReconnect: true,
        syncImmediately: true,
        maxConcurrentOperations: 2,
        enableMetrics: true,
        enableDebugLogging: false,
        syncOnWiFiOnly: false,
        maxRetries: 5,
        initialRetryDelay: Duration(seconds: 2),
        maxQueueSize: 500,
      ),
    );
    _registerHandlers();
    _initialized = true;
    CloudLogger.info('OfflineSyncService initialized');
  }

  static void _registerHandlers() {
    final sync = OfflineSyncLayer.instance;

    // Uploads bytes via StorageQueue (progress/pause/resume/cancel-capable)
    // then patches Firestore once the download URL is known. If the app is
    // killed mid-upload, this whole operation re-runs from the queue on
    // restart — StorageQueue starts a fresh UploadTask rather than
    // resuming the old one (see StorageQueue's own doc comment).
    sync.registerOperationHandler('media_upload', (data) async {
      final file = File(data['filePath'] as String);
      final storagePath = data['storagePath'] as String;
      final mediaId = data['mediaId'] as String;
      final userId = data['userId'] as String;
      final totalBytes = await file.length();
      final docRef =
          FirebaseFirestore.instance.doc(FirestorePaths.mediaDoc(userId, mediaId));

      // The 5% threshold itself is pure and unit-tested directly (see
      // shouldPersistProgress) — this closure just tracks the running
      // "last written" state across calls, which needs a real upload
      // in flight to exercise meaningfully.
      var lastWrittenFraction = 0.0;

      try {
        final downloadUrl = await _storageQueue.uploadFile(
          file: file,
          path: storagePath,
          idempotencyKey: 'upload_$mediaId',
          onProgress: (fraction) {
            _emitProgress(
              mediaId,
              MediaUploadProgress(
                mediaId: mediaId,
                fraction: fraction,
                bytesTransferred: (fraction * totalBytes).round(),
                totalBytes: totalBytes,
              ),
            );
            if (shouldPersistProgress(
                fraction: fraction, lastWritten: lastWrittenFraction)) {
              lastWrittenFraction = fraction;
              // Fire-and-forget: a dropped progress write is not worth
              // failing or delaying the upload itself over, and the
              // final 'synced' update below is what actually matters
              // for correctness — this is best-effort UI feedback only.
              docRef.update({'metadata.progress': fraction}).catchError(
                  (Object e) => CloudLogger.warning(
                      'Progress write failed for $mediaId: $e'));
            }
          },
        ).timeout(
          uploadTimeout,
          onTimeout: () => throw CloudMediaUploadFailedException(
              'Upload timed out after $uploadTimeout',
              TimeoutException('StorageQueue.uploadFile', uploadTimeout)),
        );

        await FirebaseFirestore.instance
            .doc(FirestorePaths.mediaDoc(userId, mediaId))
            .update({
          'downloadUrl': downloadUrl,
          'status': 'synced',
          'syncedAt': Timestamp.now(),
        });

        _emitProgress(
          mediaId,
          MediaUploadProgress(
            mediaId: mediaId,
            fraction: 1.0,
            bytesTransferred: totalBytes,
            totalBytes: totalBytes,
            isComplete: true,
          ),
        );
      } catch (e) {
        _emitProgress(
          mediaId,
          MediaUploadProgress(
            mediaId: mediaId,
            fraction: 0,
            bytesTransferred: 0,
            totalBytes: totalBytes,
            isFailed: true,
          ),
        );
        rethrow;
      }
    });

    sync.registerOperationHandler('media_metadata_create', (data) async {
      await FirebaseFirestore.instance
          .doc(FirestorePaths.mediaDoc(data['userId'] as String, data['mediaId'] as String))
          .set(data['documentData'] as Map<String, dynamic>);
    });

    sync.registerOperationHandler('thumbnail_upload', (data) async {
      final thumbnailPath = data['thumbnailPath'] as String;
      final thumbnailStoragePath = data['thumbnailStoragePath'] as String;
      final mediaId = data['mediaId'] as String;
      final userId = data['userId'] as String;
      final file = File(thumbnailPath);

      final thumbUrl = await _storageQueue.uploadFile(
        file: file,
        path: thumbnailStoragePath,
        idempotencyKey: 'thumb_$mediaId',
      );

      await FirebaseFirestore.instance
          .doc(FirestorePaths.mediaDoc(userId, mediaId))
          .update({'thumbnailUrl': thumbUrl});
    });

    sync.registerOperationHandler('media_delete', (data) async {
      final storagePath = data['storagePath'] as String;
      try {
        await _storageQueue.deleteFile(storagePath);
      } on FirebaseException catch (e) {
        // Already gone is fine; anything else should surface so the
        // queue can retry rather than silently dropping the delete.
        if (e.code != 'object-not-found') rethrow;
      }
      await FirebaseFirestore.instance
          .doc(FirestorePaths.mediaDoc(data['userId'] as String, data['mediaId'] as String))
          .delete();
    });
  }

  /// Queues a file upload. While it's waiting to be attempted it lives on
  /// the offline queue like any other operation; once it starts, progress
  /// and pause/resume/cancel are available via [pauseUpload],
  /// [resumeUpload], [cancelUpload] and [isUploading], keyed by [mediaId].
  static Future<void> uploadMedia({
    required String filePath, required String storagePath,
    required String userId, required String mediaId,
    required String fileName, required String mimeType,
    QueuePriority priority = QueuePriority.normal,
  }) async {
    await OfflineSyncLayer.instance.submitOperation(
      category: 'media_upload', priority: priority.value,
      idempotencyKey: 'upload_$mediaId',
      data: {'filePath': filePath, 'storagePath': storagePath,
             'userId': userId, 'mediaId': mediaId,
             'fileName': fileName, 'mimeType': mimeType},
    );
  }

  /// Queues creation of the Firestore document for a new media item.
  ///
  /// [documentData] is the *entire* document to write (typically
  /// `CloudMediaItem.toFirestore()`'s full map — userId, type, fileName,
  /// status, its own `metadata` sub-map, etc.), not just the item's
  /// `metadata` field alone. Named `documentData` rather than
  /// `metadata` specifically to avoid that confusion, since the item's
  /// own `metadata` map is only one field within it.
  static Future<void> createMediaMetadata({
    required String userId, required String mediaId,
    required Map<String, dynamic> documentData,
    QueuePriority priority = QueuePriority.high,
  }) async {
    await OfflineSyncLayer.instance.submitOperation(
      category: 'media_metadata_create', priority: priority.value,
      idempotencyKey: 'metadata_$mediaId',
      data: {'userId': userId, 'mediaId': mediaId, 'documentData': documentData},
    );
  }

  static Future<void> uploadThumbnail({
    required String thumbnailPath, required String thumbnailStoragePath,
    required String userId, required String mediaId,
  }) async {
    await OfflineSyncLayer.instance.submitOperation(
      category: 'thumbnail_upload', priority: QueuePriority.normal.value,
      idempotencyKey: 'thumb_$mediaId',
      data: {'thumbnailPath': thumbnailPath,
             'thumbnailStoragePath': thumbnailStoragePath,
             'userId': userId, 'mediaId': mediaId},
    );
  }

  static Future<void> deleteMedia({
    required String userId, required String mediaId,
    required String storagePath,
    QueuePriority priority = QueuePriority.high,
  }) async {
    await OfflineSyncLayer.instance.submitOperation(
      category: 'media_delete', priority: priority.value,
      idempotencyKey: 'delete_$mediaId',
      data: {'userId': userId, 'mediaId': mediaId, 'storagePath': storagePath},
    );
  }

  // ── Upload control passthrough: pause / resume / cancel / status ──────────
  //
  // These act on the underlying Firebase UploadTask for a media item's
  // upload_$mediaId key. They're only meaningful once the upload has
  // actually started (i.e. past the offline-queue wait — see class doc);
  // isUploading(mediaId) tells you whether that's currently the case.
  // Routed through _uploadControl (see its doc comment) rather than
  // _storageQueue directly so tests can override just this part
  // without needing a real Firebase app.

  static void pauseUpload(String mediaId) =>
      _uploadControl.pauseUpload('upload_$mediaId');

  static void resumeUpload(String mediaId) =>
      _uploadControl.resumeUpload('upload_$mediaId');

  static void cancelUpload(String mediaId) =>
      _uploadControl.cancelUpload('upload_$mediaId');

  static bool isUploading(String mediaId) =>
      _uploadControl.isUploading('upload_$mediaId');

  static bool isUploadCancelled(String mediaId) =>
      _uploadControl.isCancelled('upload_$mediaId');

  static Future<void> forceSync() => OfflineSyncLayer.instance.sync();

  static Future<int> getPendingCount() =>
      OfflineSyncLayer.instance.getPendingCount();

  static Future<List<Map<String, dynamic>>> getPendingOperations() =>
      OfflineSyncLayer.instance.getPendingOperations();

  static Future<void> clearQueue() => OfflineSyncLayer.instance.clearQueue();

  static Future<void> retryFailedOperation(String id) =>
      OfflineSyncLayer.instance.retryFailedOperation(id);

  static SyncMetrics get metrics => OfflineSyncLayer.instance.metrics;

  static bool get isInitialized => _initialized;
}
