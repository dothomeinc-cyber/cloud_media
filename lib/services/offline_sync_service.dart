import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:riverpod_offline_sync/riverpod_offline_sync.dart';
import '../constants/firestore_paths.dart';
import '../utils/logger.dart';

enum QueuePriority { critical, high, normal, low, background }

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

class OfflineSyncService {
  OfflineSyncService._();
  static bool _initialized = false;

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

    sync.registerOperationHandler('media_upload', (data) async {
      final file = File(data['filePath'] as String);
      final storagePath = data['storagePath'] as String;
      final ref = FirebaseStorage.instance.ref(storagePath);
      await ref.putFile(file, SettableMetadata(
        contentType: data['mimeType'] as String,
        customMetadata: {
          'userId': data['userId'] as String,
          'originalName': data['fileName'] as String,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      ));
      final downloadUrl = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .doc(FirestorePaths.mediaDoc(data['userId'] as String, data['mediaId'] as String))
          .update({'downloadUrl': downloadUrl, 'status': 'synced', 'syncedAt': Timestamp.now()});
      // No return value — Future<void>
    });

    sync.registerOperationHandler('media_metadata_create', (data) async {
      await FirebaseFirestore.instance
          .doc(FirestorePaths.mediaDoc(data['userId'] as String, data['mediaId'] as String))
          .set(data['metadata'] as Map<String, dynamic>);
    });

    sync.registerOperationHandler('thumbnail_upload', (data) async {
      final thumbnailPath = data['thumbnailPath'] as String;
      final file = File(thumbnailPath);
      final ref = FirebaseStorage.instance.ref(data['thumbnailStoragePath'] as String);
      await ref.putFile(
        file,
        SettableMetadata(contentType: _thumbnailContentType(thumbnailPath)),
      );
      final thumbUrl = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .doc(FirestorePaths.mediaDoc(data['userId'] as String, data['mediaId'] as String))
          .update({'thumbnailUrl': thumbUrl});
    });

    sync.registerOperationHandler('media_delete', (data) async {
      try {
        await FirebaseStorage.instance.ref(data['storagePath'] as String).delete();
      } catch (_) {}
      await FirebaseFirestore.instance
          .doc(FirestorePaths.mediaDoc(data['userId'] as String, data['mediaId'] as String))
          .delete();
    });
  }

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

  static Future<void> createMediaMetadata({
    required String userId, required String mediaId,
    required Map<String, dynamic> metadata,
    QueuePriority priority = QueuePriority.high,
  }) async {
    await OfflineSyncLayer.instance.submitOperation(
      category: 'media_metadata_create', priority: priority.value,
      idempotencyKey: 'metadata_$mediaId',
      data: {'userId': userId, 'mediaId': mediaId, 'metadata': metadata},
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

  static Future<void> forceSync() async {
    final syncLayer = OfflineSyncLayer.instance as dynamic;
    try {
      await syncLayer.forceSync();
    } on NoSuchMethodError {
      await syncLayer.sync();
    }
  }

  static String _thumbnailContentType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'webp':
        return 'image/webp';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
  static Future<int> getPendingCount() async {
    final p = await OfflineSyncLayer.instance.getPendingOperations();
    return p.length;
  }
  static Future<List<dynamic>> getPendingOperations() async =>
      OfflineSyncLayer.instance.getPendingOperations();
  static Future<void> clearQueue() async => OfflineSyncLayer.instance.clearQueue();
  static Future<void> retryFailedOperation(String id) async =>
      OfflineSyncLayer.instance.retryFailedOperation(id);
  static dynamic get metrics => OfflineSyncLayer.instance.metrics;
  static bool get isInitialized => _initialized;
}
