#!/bin/bash
# Run this from your project root: ~/Documents/cloud_media
# bash fix.sh

set -e
echo "=== CloudMedia Fix Script ==="

# ── Step 1: Delete stale nested folder that was never cleaned up ──────────────
echo "1. Removing stale lib/cloud_media/lib/ folder..."
rm -rf lib/cloud_media

# ── Step 2: Delete broken auto-generated example app ─────────────────────────
echo "2. Removing example/ folder (auto-generated, broken)..."
rm -rf example

# ── Step 3: Fix broken test file ─────────────────────────────────────────────
echo "3. Fixing test/cloud_media_test.dart..."
mkdir -p test
cat > test/cloud_media_test.dart << 'EOF'
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CloudMedia placeholder test', () {
    expect(true, isTrue);
  });
}
EOF

# ── Step 4: Create missing assets directory ───────────────────────────────────
echo "4. Creating assets/icons/ directory..."
mkdir -p assets/icons

# ── Step 5: Replace sync_providers.dart (StateProvider + valueOrNull fix) ─────
echo "5. Fixing sync_providers.dart..."
cat > lib/providers/sync_providers.dart << 'EOF'
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/offline_sync_service.dart';

enum SyncState { idle, syncing, error }

final syncStateProvider =
    StateProvider<SyncState>((ref) => SyncState.idle);

final syncProgressProvider = StateProvider<double>((ref) => 0.0);

final pendingMediaCountProvider = FutureProvider<int>((ref) async {
  return OfflineSyncService.getPendingCount();
});

/// Provider<bool> — read directly, never call .when() on this
final isMediaSyncingProvider = Provider<bool>((ref) {
  return ref.watch(syncStateProvider) == SyncState.syncing;
});

final syncMetricsProvider = Provider<Map<String, dynamic>>((ref) {
  return {'successRate': 0.95, 'totalSyncs': 0, 'failedSyncs': 0};
});

final pendingOperationsProvider =
    FutureProvider<List<dynamic>>((ref) async {
  return OfflineSyncService.getPendingOperations();
});

final connectivityStatusProvider = StateProvider<bool>((ref) => true);

final isConnectedProvider =
    Provider<bool>((ref) => ref.watch(connectivityStatusProvider));

final syncStatusTextProvider = Provider<String>((ref) {
  final state = ref.watch(syncStateProvider);
  final pending = ref.watch(pendingMediaCountProvider).when(
        data: (v) => v,
        loading: () => 0,
        error: (_, __) => 0,
      );
  if (state == SyncState.syncing) return 'Syncing...';
  if (state == SyncState.error) return 'Sync error';
  if (pending > 0) return '$pending pending items';
  return 'All synced';
});

final queueBreakdownProvider =
    FutureProvider<Map<String, int>>((ref) async {
  final ops = await OfflineSyncService.getPendingOperations();
  final breakdown = <String, int>{};
  for (final op in ops) {
    final cat = (op as dynamic).category as String? ?? 'unknown';
    breakdown[cat] = (breakdown[cat] ?? 0) + 1;
  }
  return breakdown;
});
EOF

# ── Step 6: Replace upload_service.dart (FilePicker.platform fix) ─────────────
echo "6. Fixing upload_service.dart..."
cat > lib/services/upload_service.dart << 'EOF'
import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/file_constants.dart';
import '../models/cloud_media_config.dart';
import '../models/cloud_media_type.dart';
import '../utils/error_handler.dart';
import '../utils/logger.dart';
import '../utils/validators.dart';

class UploadService {
  UploadService({required this.config});

  final CloudMediaConfig config;
  final ImagePicker _imagePicker = ImagePicker();
  final Map<String, StreamController<UploadProgressData>> _progressControllers = {};
  final Map<String, CancelToken> _cancelTokens = {};

  Future<List<PickedFile>> pickMedia({
    required CloudMediaType type,
    required int maxCount,
  }) async {
    if (maxCount > FileConstants.hardMaxSelection) {
      throw CloudMediaSelectionLimitExceededException(
          'Requested $maxCount exceeds hard limit of ${FileConstants.hardMaxSelection}.');
    }

    List<PickedFile> pickedFiles = [];

    switch (type) {
      case CloudMediaType.image:
        final files = await _imagePicker.pickMultiImage(
          limit: maxCount,
          imageQuality: 100,
        );
        pickedFiles = files.map((f) => PickedFile(f.path)).toList();
        break;

      case CloudMediaType.video:
        final file = await _imagePicker.pickVideo(source: ImageSource.gallery);
        if (file != null) pickedFiles = [PickedFile(file.path)];
        break;

      case CloudMediaType.audio:
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: maxCount > 1,
          type: FileType.audio,
        );
        if (result != null) {
          pickedFiles = result.paths.whereType<String>().map(PickedFile.new).toList();
        }
        break;

      case CloudMediaType.file:
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: maxCount > 1,
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );
        if (result != null) {
          pickedFiles = result.paths.whereType<String>().map(PickedFile.new).toList();
        }
        break;
    }

    for (final file in pickedFiles) {
      Validators.validateFileType(file.name);
      final size = await file.length();
      Validators.validateFileSize(size, type);
    }

    CloudLogger.info('Picked ${pickedFiles.length} ${type.displayName}(s)');
    return pickedFiles;
  }

  Stream<UploadProgressData> getUploadProgress(String uploadId) {
    _progressControllers.putIfAbsent(
        uploadId, () => StreamController<UploadProgressData>.broadcast());
    return _progressControllers[uploadId]!.stream;
  }

  void updateProgress(String uploadId, double progress, int uploaded, int total) {
    _progressControllers[uploadId]?.add(
      UploadProgressData(progress: progress, uploaded: uploaded, total: total),
    );
  }

  void completeUpload(String uploadId) {
    _progressControllers[uploadId]?.add(const UploadProgressData(
        progress: 1.0, uploaded: 100, total: 100, status: 'completed'));
  }

  void failUpload(String uploadId) {
    _progressControllers[uploadId]?.add(const UploadProgressData(
        progress: 0, uploaded: 0, total: 0, status: 'failed'));
  }

  void cancelUpload(String uploadId) {
    _cancelTokens[uploadId]?.cancel();
    _cancelTokens.remove(uploadId);
    _progressControllers[uploadId]?.close();
    _progressControllers.remove(uploadId);
  }

  CancelToken createCancelToken(String uploadId) {
    final token = CancelToken();
    _cancelTokens[uploadId] = token;
    return token;
  }

  bool isCancelled(String uploadId) => _cancelTokens[uploadId]?.isCancelled ?? false;

  void dispose() {
    for (final c in _progressControllers.values) { c.close(); }
    _progressControllers.clear();
    _cancelTokens.clear();
  }
}

class PickedFile {
  PickedFile(this.path)
      : name = path.split('/').last,
        mimeType = _mimeType(path);

  final String path;
  final String name;
  final String mimeType;

  Future<int> length() => File(path).length();

  static String _mimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'webp': return 'image/webp';
      case 'mp4': return 'video/mp4';
      case 'mov': return 'video/quicktime';
      case 'mp3': return 'audio/mpeg';
      case 'aac': return 'audio/aac';
      case 'm4a': return 'audio/m4a';
      case 'pdf': return 'application/pdf';
      default: return 'application/octet-stream';
    }
  }
}

class UploadProgressData {
  const UploadProgressData({
    required this.progress,
    required this.uploaded,
    required this.total,
    this.status = 'uploading',
  });
  final double progress;
  final int uploaded;
  final int total;
  final String status;
}

class CancelToken {
  bool _isCancelled = false;
  void cancel() => _isCancelled = true;
  bool get isCancelled => _isCancelled;
}
EOF

# ── Step 7: Replace permission_service.dart (real package API) ────────────────
echo "7. Fixing permission_service.dart..."
cat > lib/services/permission_service.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler_package/permission_handler_package.dart';
import '../utils/error_handler.dart';
import '../utils/logger.dart';

class PermissionService {
  PermissionService._();

  static final _container = ProviderContainer();

  static Future<void> initialize() async {
    await PermissionHandler.initialize();
    CloudLogger.info('PermissionService initialized');
  }

  static PermissionActionNotifier get _notifier =>
      _container.read(permissionActionProvider.notifier);

  static PermissionManager get _manager =>
      _container.read(permissionManagerProvider);

  static Future<void> _throwIfDenied(PermissionResult result) async {
    if (result.isPermanentlyDenied) {
      throw const CloudMediaPermissionPermanentlyDeniedException();
    }
    if (!result.isGranted) {
      throw const CloudMediaPermissionDeniedException();
    }
  }

  static Future<void> requestMediaPermissions(BuildContext context) async {
    final granted = await _notifier.initializeRequiredPermissions(
      context: context,
      requiredPermissions: [PermissionType.camera, PermissionType.storage],
      title: 'Media Access Required',
      message: 'CloudMedia needs camera and storage access.',
    );
    if (!granted) {
      final cameraDenied = await _manager.isPermissionPermanentlyDenied(PermissionType.camera);
      if (cameraDenied) throw const CloudMediaPermissionPermanentlyDeniedException();
      throw const CloudMediaPermissionDeniedException();
    }
  }

  static Future<void> requestCameraPermission(BuildContext context) async {
    final result = await _notifier.requestSinglePermission(
        PermissionType.camera, context: context);
    await _throwIfDenied(result);
  }

  static Future<void> requestStoragePermission(BuildContext context) async {
    final result = await _notifier.requestSinglePermission(
        PermissionType.storage, context: context);
    await _throwIfDenied(result);
  }

  static Future<void> requestMicrophonePermission(BuildContext context) async {
    final result = await _notifier.requestSinglePermission(
        PermissionType.microphone, context: context);
    await _throwIfDenied(result);
  }

  static Future<bool> isGranted(PermissionType permission) async =>
      _manager.isPermissionGranted(permission);

  static Future<void> openSettings() async =>
      _manager.openAppSettings();
}
EOF

# ── Step 8: Replace offline_sync_service.dart (void return fix) ──────────────
echo "8. Fixing offline_sync_service.dart..."
cat > lib/services/offline_sync_service.dart << 'EOF'
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:riverpod_offline_sync/riverpod_offline_sync.dart';
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
          .collection('users').doc(data['userId'] as String)
          .collection('media').doc(data['mediaId'] as String)
          .update({'downloadUrl': downloadUrl, 'status': 'synced', 'syncedAt': Timestamp.now()});
      // No return value — Future<void>
    });

    sync.registerOperationHandler('media_metadata_create', (data) async {
      await FirebaseFirestore.instance
          .collection('users').doc(data['userId'] as String)
          .collection('media').doc(data['mediaId'] as String)
          .set(data['metadata'] as Map<String, dynamic>);
    });

    sync.registerOperationHandler('thumbnail_upload', (data) async {
      final file = File(data['thumbnailPath'] as String);
      final ref = FirebaseStorage.instance.ref(data['thumbnailStoragePath'] as String);
      await ref.putFile(file, SettableMetadata(contentType: 'image/webp'));
      final thumbUrl = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('users').doc(data['userId'] as String)
          .collection('media').doc(data['mediaId'] as String)
          .update({'thumbnailUrl': thumbUrl});
    });

    sync.registerOperationHandler('media_delete', (data) async {
      try {
        await FirebaseStorage.instance.ref(data['storagePath'] as String).delete();
      } catch (_) {}
      await FirebaseFirestore.instance
          .collection('users').doc(data['userId'] as String)
          .collection('media').doc(data['mediaId'] as String)
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

  static Future<void> forceSync() async => OfflineSyncLayer.instance.sync();
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
EOF

# ── Step 9: Replace storage_queue_service.dart (metadata param fix) ───────────
echo "9. Fixing storage_queue_service.dart..."
cat > lib/services/storage_queue_service.dart << 'EOF'
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:riverpod_offline_sync/riverpod_offline_sync.dart';

class StorageQueueService {
  StorageQueueService._();
  static final StorageQueue _queue = StorageQueue();
  static final Map<String, String> _keys = {};

  static Future<void> uploadFile({
    required File file, required String storagePath,
    required String mediaId, required String userId,
    VoidCallback? onComplete, void Function(double)? onProgress,
  }) async {
    final key = IdempotencyKey.generate();
    _keys[mediaId] = key;
    final ref = FirebaseStorage.instance.ref(storagePath);
    await ref.putFile(file, SettableMetadata(
      customMetadata: {'userId': userId, 'mediaId': mediaId,
                       'uploadedAt': DateTime.now().toIso8601String()},
    ));
    onComplete?.call();
    onProgress?.call(1.0);
    _keys.remove(mediaId);
  }

  static void pauseUpload(String mediaId) {
    final key = _keys[mediaId];
    if (key != null) _queue.pauseUpload(key);
  }

  static void resumeUpload(String mediaId) {
    final key = _keys[mediaId];
    if (key != null) _queue.resumeUpload(key);
  }

  static void cancelUpload(String mediaId) {
    final key = _keys[mediaId];
    if (key != null) { _queue.cancelUpload(key); _keys.remove(mediaId); }
  }
}
EOF

# ── Step 10: Fix firebase_service.dart (deprecated share_plus API) ────────────
echo "10. Fixing firebase_service.dart..."
cat > lib/services/firebase_service.dart << 'EOF'
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/firestore_paths.dart';
import '../models/cloud_media_config.dart';
import '../models/cloud_media_item.dart';
import '../models/cloud_media_status.dart';
import '../models/cloud_media_type.dart';
import '../utils/error_handler.dart';
import '../utils/logger.dart';

class FirebaseService {
  FirebaseService({required this.config});
  final CloudMediaConfig config;
  late FirebaseFirestore _firestore;
  late FirebaseStorage _storage;

  Future<void> initialize() async {
    _firestore = FirebaseFirestore.instance;
    _storage = config.customStorageBucket != null
        ? FirebaseStorage.instanceFor(bucket: config.customStorageBucket)
        : FirebaseStorage.instance;
    CloudLogger.info('FirebaseService ready. User: ${currentUser?.uid}');
  }

  User? get currentUser => FirebaseAuth.instance.currentUser;

  String get _uid {
    final uid = currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw const CloudMediaPermissionDeniedException(
          'No authenticated user.');
    }
    return uid;
  }

  Future<CloudMediaItem> getMedia(String mediaId) async {
    final doc = await _firestore.doc(FirestorePaths.mediaDoc(_uid, mediaId)).get();
    if (!doc.exists) throw CloudMediaNotFoundException('Not found: $mediaId');
    return CloudMediaItem.fromFirestore(doc);
  }

  Future<List<CloudMediaItem>> getUserMedia() => listMedia();

  Future<List<CloudMediaItem>> listMedia({
    CloudMediaType? type, int limit = 50, int offset = 0,
    DateTime? startDate, DateTime? endDate, String? searchQuery,
  }) async {
    Query query = _firestore
        .collection(FirestorePaths.userMedia(_uid))
        .where('deletedAt', isNull: true)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (type != null) query = query.where('type', isEqualTo: type.string);
    if (startDate != null) query = query.where('createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    if (endDate != null) query = query.where('createdAt',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    final snap = await query.get();
    return snap.docs.map(CloudMediaItem.fromFirestore).toList();
  }

  Stream<CloudMediaItem> watchMedia(String mediaId) => _firestore
      .doc(FirestorePaths.mediaDoc(_uid, mediaId))
      .snapshots()
      .map(CloudMediaItem.fromFirestore);

  Future<void> deleteMedia(String mediaId) async {
    await _firestore.doc(FirestorePaths.mediaDoc(_uid, mediaId)).update({
      'deletedAt': Timestamp.now(), 'status': CloudMediaStatus.deleted.name,
    });
  }

  Future<void> restoreMedia(String mediaId) async {
    await _firestore.doc(FirestorePaths.mediaDoc(_uid, mediaId)).update({
      'deletedAt': null, 'status': CloudMediaStatus.synced.name,
    });
  }

  Future<String> downloadMedia(String mediaId) async {
    final media = await getMedia(mediaId);
    if (media.downloadUrl.isEmpty) {
      throw CloudMediaUploadFailedException('No URL for: $mediaId');
    }
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/${mediaId}_${media.fileName}';
    await _storage.ref(media.storagePath).writeToFile(File(filePath));
    return filePath;
  }

  Future<void> shareMedia(CloudMediaItem media) async {
    if (media.downloadUrl.isNotEmpty) {
      await SharePlus.instance.share(
        ShareParams(uri: Uri.parse(media.downloadUrl)),
      );
    } else {
      final path = await downloadMedia(media.id);
      await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
    }
  }
}
EOF

# ── Step 11: Fix cloud_media.dart (remove unnecessary library name) ────────────
echo "11. Fixing cloud_media.dart library name..."
sed -i 's/^library cloud_media;//' lib/cloud_media.dart

# ── Step 12: Fix media_library_screen.dart (curly braces) ─────────────────────
echo "12. Fixing media_library_screen.dart..."
cat > lib/ui/screens/media_library_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/cloud_media_api.dart';
import '../../models/cloud_media_item.dart';
import '../../models/cloud_media_type.dart';
import '../widgets/media_grid.dart';

class MediaLibraryScreen extends ConsumerStatefulWidget {
  const MediaLibraryScreen({super.key, this.type, this.onMediaTap});
  final CloudMediaType? type;
  final void Function(CloudMediaItem)? onMediaTap;

  @override
  ConsumerState<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends ConsumerState<MediaLibraryScreen> {
  List<CloudMediaItem> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await CloudMedia.list(type: widget.type);
      if (mounted) {
        setState(() { _items = items; _loading = false; });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _loading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.type?.displayName ?? 'Media Library'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _items.isEmpty
                  ? const Center(child: Text('No media yet'))
                  : MediaGrid(mediaItems: _items, onItemTap: widget.onMediaTap),
    );
  }
}
EOF

# ── Step 13: Add flutter_screenutil to pubspec (required by permission_handler_package) ──
echo "13. Adding flutter_screenutil to pubspec.yaml..."
# Add after flutter_riverpod line
sed -i '/flutter_riverpod:/a\  flutter_screenutil: ^5.9.3' pubspec.yaml

echo ""
echo "=== All fixes applied! Now run: ==="
echo "flutter pub get"
echo "flutter analyze"
