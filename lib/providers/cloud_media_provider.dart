import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler_package/permission_handler_package.dart';
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
import '../services/permission_service.dart';
import '../services/thumbnail_service.dart';
import '../services/upload_service.dart';
import '../ui/screens/editor_screen.dart';
import '../ui/screens/review_screen.dart';
import '../utils/error_handler.dart';
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

    // Apply the config's logging preference before anything else logs —
    // enableLogging was previously defined on CloudMediaConfig but never
    // actually wired to CloudLogger, so every app got CloudLogger's
    // default of always-on regardless of what they configured.
    CloudLogger.isEnabled = config.enableLogging;

    // Same story as enableLogging above: uploadTimeout was fully
    // modeled on CloudMediaConfig (constructor, copyWith, toJson) but
    // never actually applied anywhere, so a configured timeout
    // silently did nothing — uploads could hang indefinitely.
    OfflineSyncService.uploadTimeout = config.uploadTimeout;

    // NOTE: Firebase + riverpod_offline_sync must be initialized by the host app.
    await OfflineSyncService.initialize();

    // Required for PermissionManager().markInitialized() to have run
    // before _ensureReadPermission's first real call — without it,
    // registerNavigatorKey/setCurrentContext calls the host app makes
    // queue up in PermissionManager's _pendingCallbacks indefinitely,
    // and requestPermissionWithExplanation's own one-tick fallback
    // delay isn't a guarantee this has actually completed by then.
    await PermissionService.initialize();

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

  /// Requests whatever read-access permission is needed to pick [type]
  /// from the gallery/file system, using
  /// [PermissionService.readPermissionFor]'s type→permission mapping —
  /// the same one [PermissionService.requestMediaReadPermission] uses —
  /// so both pick paths (this one, used by `CloudMedia.pick()`; and the
  /// standalone `MediaPickerScreen` / `PermissionAwareMediaPicker`
  /// widgets) can never silently diverge on which permission gets
  /// requested for which media type.
  ///
  /// This deliberately talks to [PermissionManager] directly rather than
  /// through `permissionActionProvider` (which needs a `WidgetRef`) —
  /// [CloudMediaProvider] is a plain Dart class with no Riverpod `ref`
  /// of its own, by design, so `CloudMedia.pick()` keeps working from
  /// call sites that only have a `BuildContext` (or none at all). Both
  /// paths ultimately reach the same [PermissionManager] singleton, so
  /// permission state and its 3-second cache stay consistent either way
  /// — but the UI differs: this path shows [PermissionManager]'s own
  /// popup dialogs (via [PermissionManager.requestPermissionWithExplanation]),
  /// while `PermissionAwareMediaPicker` / `MediaPickerScreen` show the
  /// canonical full-screen flow from `permissionActionProvider`. If your
  /// app wants the full-screen flow for `CloudMedia.pick()` too, drive
  /// permissions yourself via `PermissionService` before calling
  /// `CloudMedia.pick()`, which will then see the permission already
  /// granted and skip this step's own dialog entirely.
  ///
  /// Throws [CloudMediaPermissionDeniedException] or
  /// [CloudMediaPermissionPermanentlyDeniedException] on denial —
  /// [PermissionManager.requestPermissionWithExplanation] already shows
  /// its own explanation / permanently-denied dialogs when [context] is
  /// supplied (or falls back to whatever context the manager has been
  /// given via `registerNavigatorKey`/`setCurrentContext`; with neither,
  /// it still requests the OS permission, just without any dialog).
  Future<void> _ensureReadPermission(
    CloudMediaType type,
    BuildContext? context,
  ) async {
    final permission = PermissionService.readPermissionFor(type);

    final result = await PermissionManager().requestPermissionWithExplanation(
      permission,
      context: context,
    );

    if (result.isPermanentlyDenied) {
      throw const CloudMediaPermissionPermanentlyDeniedException();
    }
    // See PermissionService._throwIfDenied's comment: isSufficient
    // treats limited/provisional access as usable rather than a denial.
    if (!result.isSufficient) {
      throw const CloudMediaPermissionDeniedException();
    }
  }

  // ── Pick ────────────────────────────────────────────────────────────────────

  Future<List<CloudMediaItem>> pickMedia({
    required CloudMediaType type,
    required int maxCount,
    BuildContext? context,
    bool enableEditing = false,
    bool enableBackgroundRemoval = false,
    bool showPreview = false,
    String? folder,
    String? subFolder,
    CompressionProfile? compressionProfile,
  }) async {
    _ensureInit();
    try {
      await _ensureReadPermission(type, context);

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
          documentData: mediaItem.toFirestore(),
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


  /// Sanitizes a caller-supplied folder/subFolder path segment for safe
  /// use in a Firestore document path / Storage object path.
  ///
  /// Path traversal is neutralized character-by-character (`.` isn't in
  /// the allowed set, so `..` becomes `__`, not a real `..` segment —
  /// verified this can't reconstruct a traversal even across multiple
  /// `/`-separated parts). Also caps the sanitized result's length,
  /// since Firestore/Storage both enforce their own real path-length
  /// limits server-side — better to reject an absurdly long
  /// caller-supplied folder name here, clearly, than let it fail later
  /// as an opaque Firestore/Storage error.
  String? _sanitizeFolder(String? folder) {
    final raw = folder?.trim();
    if (raw == null || raw.isEmpty) return null;

    final cleaned = raw
        .split('/')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => part.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_'))
        .where((part) => part.isNotEmpty)
        .join('/');

    if (cleaned.isEmpty) return null;
    // 200 chars leaves ample room for the rest of a storage path
    // (users/$uid/media/$folder/$subFolder/$mediaId/$fileName) to stay
    // well under Storage's/Firestore's own limits even for a long uid
    // or file name.
    const maxLength = 200;
    return cleaned.length > maxLength ? cleaned.substring(0, maxLength) : cleaned;
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
    if (lower.endsWith('.m4a')) return 'audio/m4a';
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

  /// Watches [mediaId], sharing one underlying Firestore listener across
  /// repeated calls for the same id (so several widgets watching the
  /// same item don't each open their own listener).
  ///
  /// If the underlying Firestore listener terminates with an error —
  /// which it does permanently after errors like permission-denied
  /// (Firestore's own documented behavior: "After an error, the
  /// listener will not receive any more events" — this is genuinely
  /// reachable here, e.g. the user signs out mid-watch and the security
  /// rules that granted access are gone) — the cached entry is torn
  /// down so the *next* [watchMedia] call for the same id establishes a
  /// fresh listener instead of permanently returning a dead stream.
  /// Already-subscribed listeners on the stream still see the error via
  /// [StreamController.addError] as before; this only affects future
  /// calls to [watchMedia].
  Stream<CloudMediaItem> watchMedia(String mediaId) {
    _ensureInit();
    if (!_watchControllers.containsKey(mediaId)) {
      final controller = StreamController<CloudMediaItem>.broadcast();
      _watchControllers[mediaId] = controller;
      final sub = _firebaseService.watchMedia(mediaId).listen(
        controller.add,
        onError: (Object error, StackTrace stackTrace) {
          controller.addError(error, stackTrace);
          _watchSubscriptions.remove(mediaId)?.cancel();
          _watchControllers.remove(mediaId);
        },
      );
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

  // ── Upload lifecycle: progress / pause / resume / cancel ───────────────────
  //
  // Meaningful once a given mediaId's upload has actually started (past the
  // offline-queue wait) — see OfflineSyncService's class doc.

  /// Live progress for [mediaId]'s upload. Emits until it completes or fails.
  Stream<UploadProgressData> watchUploadProgress(String mediaId) {
    _ensureInit();
    return _uploadService.getUploadProgress(mediaId);
  }

  /// Pause an in-flight upload. No-op if [mediaId] isn't currently uploading.
  void pauseUpload(String mediaId) {
    _ensureInit();
    _uploadService.pauseUpload(mediaId);
  }

  /// Resume a paused upload. No-op if [mediaId] isn't currently uploading.
  void resumeUpload(String mediaId) {
    _ensureInit();
    _uploadService.resumeUpload(mediaId);
  }

  /// Cancel an in-flight upload. No-op if [mediaId] isn't currently uploading.
  void cancelUpload(String mediaId) {
    _ensureInit();
    _uploadService.cancelUpload(mediaId);
  }

  /// True while [mediaId]'s upload is actively talking to Firebase Storage.
  bool isUploading(String mediaId) {
    _ensureInit();
    return _uploadService.isUploading(mediaId);
  }

  Future<void> clearCache() async {
    _ensureInit();
    await _cacheService.clearAll();
  }

  Future<int> getCacheSize() async {
    _ensureInit();
    return _cacheService.getCacheSize();
  }

  /// Cancels all active [watchMedia] subscriptions, closes their
  /// controllers, and disposes [_uploadService] and [_cacheService]
  /// (which closes its underlying Hive box).
  Future<void> dispose() async {
    for (final sub in _watchSubscriptions.values) {
      sub.cancel();
    }
    _watchSubscriptions.clear();
    for (final c in _watchControllers.values) {
      c.close();
    }
    _watchControllers.clear();
    _uploadService.dispose();
    await _cacheService.dispose();
  }
}
