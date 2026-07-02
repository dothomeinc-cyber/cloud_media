import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/cloud_media_config.dart';
import '../models/cloud_media_item.dart';
import '../models/cloud_media_status.dart';
import '../models/cloud_media_type.dart';
import '../models/compression_profile.dart';
import '../services/cache_service.dart';
import '../services/background_removal_service.dart';
import '../services/compression_service.dart';
import '../services/firebase_service.dart';
import '../services/offline_sync_service.dart';
import '../services/thumbnail_service.dart';
import '../services/upload_service.dart';
import '../ui/screens/editor_screen.dart';
import '../ui/screens/review_screen.dart';
import '../utils/logger.dart';

class CloudMediaProvider {
  CloudMediaProvider({required this.config});

  final CloudMediaConfig config;

  late final FirebaseService _firebaseService;
  late final UploadService _uploadService;
  late final CacheService _cacheService;
  late final CompressionService _compressionService;
  late final ThumbnailService _thumbnailService;
  late final BackgroundRemovalService _backgroundRemovalService;

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
    _backgroundRemovalService = const BackgroundRemovalService();

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
    BuildContext? context,
    bool enableEditing = true,
    bool enableBackgroundRemoval = false,
    bool showPreview = false,
    String? folder,
    String? subFolder,
    CompressionProfile? compressionProfile,
  }) async {
    _ensureInit();
    try {
      final pickedFiles =
          await _uploadService.pickMedia(type: type, maxCount: maxCount);
      final uid = _firebaseService.currentUser?.uid ?? '';
      final items = <CloudMediaItem>[];
      final thumbnailPaths = <String?>[];  // parallel to items

      // Resolve effective quality/thumbnail from compressionProfile or config
      final effectiveQuality = compressionProfile?.imageQuality ?? config.imageQuality;
      final effectiveThumb = compressionProfile?.thumbnailSize ?? config.thumbnailSize;
      final effectiveCompress = compressionProfile?.compress ?? config.compressAutomatically;

      for (final file in pickedFiles) {
        final mediaId = const Uuid().v4();

        String processedPath = file.path;

        if (type == CloudMediaType.image) {
          if (enableEditing && context != null && context.mounted) {
            final editedPath = await CloudMediaImageEditor.edit(
              context: context,
              imagePath: processedPath,
            );
            if (editedPath != null && editedPath.isNotEmpty) {
              processedPath = editedPath;
            }
          } else if (enableEditing && context == null) {
            CloudLogger.warning(
              'enableEditing=true was ignored because no BuildContext was passed to CloudMedia.pick(context: ...).',
            );
          }

          if (enableBackgroundRemoval) {
            processedPath = await _backgroundRemovalService.removeBackground(
              processedPath,
              cropToSubject: true,
            );
          }

          if (effectiveCompress) {
            processedPath = await _compressionService.compressImage(
              processedPath,
              quality: effectiveQuality,
            );
          }
        }

        String? thumbnailPath;
        if (config.autoGenerateThumbnails) {
          thumbnailPath = await _thumbnailService.generateThumbnail(
            processedPath,
            type,
            size: effectiveThumb,
          );
        }

        // Build storage path: users/{uid}/media/{folder}/{subFolder}/{mediaId}/{file}
        final safeFolder = _sanitizeFolder(folder);
        final safeSubFolder = _sanitizeFolder(subFolder);
        String mediaBasePath = 'users/$uid/media';
        if (safeFolder != null) mediaBasePath += '/$safeFolder';
        if (safeSubFolder != null) mediaBasePath += '/$safeSubFolder';

        final processedFileName = processedPath.split('/').last;
        final storagePath = '$mediaBasePath/$mediaId/$processedFileName';
        final fileSize = await PickedFile(processedPath).length();

        final mediaItem = CloudMediaItem(
          id: mediaId,
          userId: uid,
          type: type,
          fileName: processedFileName,
          mimeType: _mimeTypeForPath(processedPath, fallback: file.mimeType),
          size: fileSize,
          storagePath: storagePath,
          downloadUrl: '',
          thumbnailUrl: '',
          status: CloudMediaStatus.pending,
          createdAt: DateTime.now(),
          localPath: processedPath,
        );

        items.add(mediaItem);
        thumbnailPaths.add(thumbnailPath);
      }

      // Show preview/review screen before committing uploads
      if (showPreview && context != null && context.mounted && items.isNotEmpty) {
        final confirmed = await _showPreview(context, items);
        if (!confirmed) return [];
      }

      // Commit uploads for confirmed items
      final uid2 = _firebaseService.currentUser?.uid ?? '';
      for (var i = 0; i < items.length; i++) {
        final mediaItem = items[i];
        final thumbPath = thumbnailPaths[i];

        await OfflineSyncService.createMediaMetadata(
          userId: uid2,
          mediaId: mediaItem.id,
          metadata: mediaItem.toFirestore(),
          priority: QueuePriority.high,
        );

        await OfflineSyncService.uploadMedia(
          filePath: mediaItem.localPath!,
          storagePath: mediaItem.storagePath,
          userId: uid2,
          mediaId: mediaItem.id,
          fileName: mediaItem.fileName,
          mimeType: mediaItem.mimeType,
          priority: QueuePriority.normal,
        );

        if (thumbPath != null) {
          final thumbStoragePath =
              'users/$uid2/thumbnails/${mediaItem.id}.${_fileExtension(thumbPath)}';
          await OfflineSyncService.uploadThumbnail(
            thumbnailPath: thumbPath,
            thumbnailStoragePath: thumbStoragePath,
            userId: uid2,
            mediaId: mediaItem.id,
          );
        }
      }

      return items;
    } catch (e, st) {
      CloudLogger.error('pickMedia failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<bool> _showPreview(
      BuildContext context, List<CloudMediaItem> items) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          mediaItems: items,
          onConfirm: () => Navigator.of(context).pop(true),
          onCancel: () => Navigator.of(context).pop(false),
        ),
      ),
    );
    return result ?? false;
  }


  String? _sanitizeFolder(String? folder) {
    final raw = folder?.trim();
    if (raw == null || raw.isEmpty) return null;

    final cleaned = raw
        .split('/')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => part.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_'))
        .where((part) => part.isNotEmpty)
        .join('/');

    return cleaned.isEmpty ? null : cleaned;
  }

  String _fileExtension(String path) {
    final name = path.split('/').last;
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == name.length - 1) return 'jpg';
    return name.substring(dotIndex + 1).toLowerCase();
  }


  String _mimeTypeForPath(String path, {String? fallback}) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return fallback ?? 'application/octet-stream';
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

  Future<int> getCacheSize() async {
    _ensureInit();
    return _cacheService.getCacheSize();
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
