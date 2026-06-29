import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/cloud_media_config.dart';
import '../models/cloud_media_item.dart';
import '../models/cloud_media_status.dart';
import '../models/cloud_media_type.dart';
import '../services/cache_service.dart';
import '../services/compression_service.dart';
import '../services/firebase_service.dart';
import '../services/offline_sync_service.dart';
import '../services/thumbnail_service.dart';
import '../services/upload_service.dart';
import '../utils/logger.dart';

class CloudMediaProvider {
  CloudMediaProvider({required this.config});

  final CloudMediaConfig config;

  late final FirebaseService _firebaseService;
  late final UploadService _uploadService;
  late final CacheService _cacheService;
  late final CompressionService _compressionService;
  late final ThumbnailService _thumbnailService;

  final Map<String, StreamController<CloudMediaItem>> _watchControllers = {};
  final Map<String, StreamSubscription<CloudMediaItem>> _watchSubscriptions = {};
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // NOTE: Firebase + riverpod_offline_sync must be initialized by the host app.
    await OfflineSyncService.initialize();

    _firebaseService = FirebaseService(config: config);
    _uploadService = UploadService(config: config);
    _cacheService = CacheService(config: config);
    _compressionService = CompressionService(config: config);
    _thumbnailService = ThumbnailService(config: config);

    await _firebaseService.initialize();
    await _cacheService.initialize();

    _initialized = true;
    CloudLogger.info('CloudMediaProvider initialized');
  }

  void _ensureInit() {
    if (!_initialized) {
      throw StateError(
          'CloudMediaProvider not initialized. Call initialize() first.');
    }
  }

  // ── Pick ────────────────────────────────────────────────────────────────────

  Future<List<CloudMediaItem>> pickMedia({
    required CloudMediaType type,
    required int maxCount,
    bool enableEditing = true,
    bool enableBackgroundRemoval = false,
  }) async {
    _ensureInit();
    try {
      final pickedFiles =
          await _uploadService.pickMedia(type: type, maxCount: maxCount);
      final uid = _firebaseService.currentUser?.uid ?? '';
      final items = <CloudMediaItem>[];

      for (final file in pickedFiles) {
        final mediaId = const Uuid().v4();

        // Compress images (WebP, quality 85)
        String processedPath = file.path;
        if (config.compressAutomatically && type == CloudMediaType.image) {
          processedPath = await _compressionService.compressImage(
            file.path,
            quality: config.imageQuality,
          );
        }

        // Generate thumbnail (200×200 WebP, on-device)
        String? thumbnailPath;
        if (config.autoGenerateThumbnails) {
          thumbnailPath = await _thumbnailService.generateThumbnail(
            processedPath,
            type,
            size: config.thumbnailSize,
          );
        }

        final storagePath = 'users/$uid/media/$mediaId/${file.name}';
        final thumbStoragePath = 'users/$uid/thumbnails/$mediaId.webp';
        final fileSize = await file.length();

        final mediaItem = CloudMediaItem(
          id: mediaId,
          userId: uid,
          type: type,
          fileName: file.name,
          mimeType: file.mimeType,
          size: fileSize,
          storagePath: storagePath,
          downloadUrl: '',
          thumbnailUrl: '',
          status: CloudMediaStatus.pending,
          createdAt: DateTime.now(),
          localPath: processedPath,
        );

        // Metadata first (high priority), then file upload
        await OfflineSyncService.createMediaMetadata(
          userId: uid,
          mediaId: mediaId,
          metadata: mediaItem.toFirestore(),
          priority: QueuePriority.high,
        );

        await OfflineSyncService.uploadMedia(
          filePath: processedPath,
          storagePath: storagePath,
          userId: uid,
          mediaId: mediaId,
          fileName: file.name,
          mimeType: file.mimeType,
          priority: QueuePriority.normal,
        );

        if (thumbnailPath != null) {
          await OfflineSyncService.uploadThumbnail(
            thumbnailPath: thumbnailPath,
            thumbnailStoragePath: thumbStoragePath,
            userId: uid,
            mediaId: mediaId,
          );
        }

        items.add(mediaItem);
      }

      return items;
    } catch (e, st) {
      CloudLogger.error('pickMedia failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── List ────────────────────────────────────────────────────────────────────

  Future<List<CloudMediaItem>> listMedia({
    CloudMediaType? type,
    int limit = 50,
    int offset = 0,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    _ensureInit();
    return _firebaseService.listMedia(
      type: type,
      limit: limit,
      offset: offset,
      startDate: startDate,
      endDate: endDate,
      searchQuery: searchQuery,
    );
  }

  // ── Watch ───────────────────────────────────────────────────────────────────

  Stream<CloudMediaItem> watchMedia(String mediaId) {
    _ensureInit();
    if (!_watchControllers.containsKey(mediaId)) {
      final controller = StreamController<CloudMediaItem>.broadcast();
      _watchControllers[mediaId] = controller;
      final sub = _firebaseService
          .watchMedia(mediaId)
          .listen(controller.add, onError: controller.addError);
      _watchSubscriptions[mediaId] = sub;
    }
    return _watchControllers[mediaId]!.stream;
  }

  // ── Delete / Restore ────────────────────────────────────────────────────────

  Future<void> deleteMedia(String mediaId) async {
    _ensureInit();
    final media = await _firebaseService.getMedia(mediaId);
    await OfflineSyncService.deleteMedia(
      userId: media.userId,
      mediaId: media.id,
      storagePath: media.storagePath,
      priority: QueuePriority.high,
    );
    await _cacheService.remove(mediaId);
  }

  Future<void> restoreMedia(String mediaId) async {
    _ensureInit();
    await _firebaseService.restoreMedia(mediaId);
  }

  // ── Get / Download / Share ──────────────────────────────────────────────────

  Future<CloudMediaItem> getMedia(String mediaId) async {
    _ensureInit();
    return _firebaseService.getMedia(mediaId);
  }

  Future<String> downloadMedia(String mediaId) async {
    _ensureInit();
    final cached = await _cacheService.get(mediaId);
    if (cached != null) return cached;

    final media = await _firebaseService.getMedia(mediaId);
    final localPath = await _firebaseService.downloadMedia(mediaId);
    await _cacheService.set(mediaId, localPath, media.size);
    return localPath;
  }

  Future<void> shareMedia(String mediaId) async {
    _ensureInit();
    final media = await _firebaseService.getMedia(mediaId);
    await _firebaseService.shareMedia(media);
  }

  // ── Sync / Cache ─────────────────────────────────────────────────────────────

  Future<void> forceSync() async {
    _ensureInit();
    await OfflineSyncService.forceSync();
  }

  Future<int> getPendingCount() async {
    _ensureInit();
    return OfflineSyncService.getPendingCount();
  }

  Future<void> clearCache() async {
    _ensureInit();
    await _cacheService.clearAll();
  }

  void dispose() {
    for (final sub in _watchSubscriptions.values) {
      sub.cancel();
    }
    _watchSubscriptions.clear();
    for (final c in _watchControllers.values) {
      c.close();
    }
    _watchControllers.clear();
    _uploadService.dispose();
  }
}
