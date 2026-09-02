import 'package:flutter/material.dart';
import '../models/cloud_media_config.dart';
import '../models/cloud_media_item.dart';
import '../models/cloud_media_type.dart';
import '../models/compression_profile.dart';
import '../providers/cloud_media_provider.dart';
import '../services/upload_service.dart';
import '../ui/dialogs/confirmation_dialog.dart';
import '../utils/error_handler.dart';

/// The primary public API for the CloudMedia package.
///
/// Initialize once in `main()` before using any other methods:
/// ```dart
/// await CloudMedia.initialize(config: CloudMediaConfig());
/// ```
class CloudMedia {
  CloudMedia._();

  static CloudMediaProvider? _provider;
  static CloudMediaConfig _config = const CloudMediaConfig();
  static bool _initialized = false;

  /// Internal accessor — used by Riverpod providers without creating a second instance.
  static CloudMediaProvider get provider {
    _ensure();
    return _provider!;
  }

  /// The active config. Available after [initialize].
  static CloudMediaConfig get config => _config;

  /// Initialize CloudMedia. Call once in main() after Firebase.initializeApp().
  ///
  /// Safe to call more than once — subsequent calls are a no-op, matching
  /// the guarded pattern `CloudMediaProvider.initialize()`,
  /// `OfflineSyncService.initialize()`, and `PermissionHandler.initialize()`
  /// all already use. This avoids silently replacing the active
  /// `CloudMediaProvider` (and the services it constructs) out from under
  /// anything already holding a reference to the config or provider — e.g.
  /// `UploadNotifier` reads `CloudMedia.config` once, at construction time,
  /// so a second `initialize()` call with a different config would
  /// otherwise leave already-constructed instances silently using the old
  /// one.
  ///
  /// ```dart
  /// await CloudMedia.initialize(
  ///   config: const CloudMediaConfig(imageQuality: 85),
  /// );
  /// ```
  static Future<void> initialize({
    CloudMediaConfig config = const CloudMediaConfig(),
  }) async {
    if (_initialized) return;
    _config = config;
    _provider = CloudMediaProvider(config: _config);
    await _provider!.initialize();
    _initialized = true;
  }

  /// Pick one or more media files from the device.
  ///
  /// ```dart
  /// // Simple image pick
  /// final items = await CloudMedia.pick(context: context);
  ///
  /// // Product image with editing, preview, custom folder, compression profile
  /// final items = await CloudMedia.pick(
  ///   context: context,
  ///   type: CloudMediaType.image,
  ///   enableEditing: true,
  ///   showPreview: true,
  ///   folder: 'products',
  ///   subFolder: productId,
  ///   compressionProfile: CompressionProfile.product,
  /// );
  ///
  /// // Background removal
  /// final items = await CloudMedia.pick(
  ///   context: context,
  ///   enableBackgroundRemoval: true,
  /// );
  /// ```
  ///
  /// If [showPreview] is true, the user sees a review screen after picking
  /// and can confirm or cancel before the upload begins.
  ///
  /// If [compressionProfile] is set it overrides the [CloudMediaConfig]
  /// quality and thumbnail size for this pick only.
  ///
  /// Requests the OS permission needed to read [type] from the gallery/
  /// file system before picking (camera permission is not requested —
  /// this always picks from the gallery/file system, never the camera).
  /// Throws [CloudMediaPermissionDeniedException] if denied, or
  /// [CloudMediaPermissionPermanentlyDeniedException] if permanently
  /// denied — catch these to show your own messaging, or let them
  /// propagate. Passing [context] lets the permission package show its
  /// own explanation/settings dialogs; without one, the permission is
  /// still requested, just without any dialog.
  ///
  /// Storage path layout:
  ///   `users/{uid}/media/{folder}/{subFolder}/{mediaId}/{fileName}`
  static Future<List<CloudMediaItem>> pick({
    BuildContext? context,
    CloudMediaType type = CloudMediaType.image,
    int maxCount = 1,
    bool enableEditing = false,
    bool enableBackgroundRemoval = false,
    bool showPreview = false,
    String? folder,
    String? subFolder,
    CompressionProfile? compressionProfile,
  }) async {
    _ensure();
    return _provider!.pickMedia(
      type: type,
      context: context,
      maxCount: maxCount,
      enableEditing: enableEditing,
      enableBackgroundRemoval: enableBackgroundRemoval,
      showPreview: showPreview,
      folder: folder,
      subFolder: subFolder,
      compressionProfile: compressionProfile,
    );
  }

  /// List all media for the current user with optional filters.
  ///
  /// ```dart
  /// final all    = await CloudMedia.list();
  /// final images = await CloudMedia.list(type: CloudMediaType.image);
  /// final recent = await CloudMedia.list(
  ///   startDate: DateTime.now().subtract(const Duration(days: 7)),
  /// );
  /// ```
  static Future<List<CloudMediaItem>> list({
    CloudMediaType? type,
    int limit = 50,
    int offset = 0,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    _ensure();
    return _provider!.listMedia(
      type: type,
      limit: limit,
      offset: offset,
      startDate: startDate,
      endDate: endDate,
      searchQuery: searchQuery,
    );
  }

  /// Watch real-time status updates for a single media item.
  ///
  /// ```dart
  /// CloudMedia.watch(item.id).listen((updated) {
  ///   if (updated.status == CloudMediaStatus.synced) {
  ///     print(updated.downloadUrl);
  ///   }
  /// });
  /// ```
  static Stream<CloudMediaItem> watch(String mediaId) {
    _ensure();
    return _provider!.watchMedia(mediaId);
  }

  /// Fetch a single media item by id.
  static Future<CloudMediaItem> get(String mediaId) async {
    _ensure();
    return _provider!.getMedia(mediaId);
  }

  /// Delete by media id. Queued if offline.
  static Future<void> delete(String mediaId) async {
    _ensure();
    await _provider!.deleteMedia(mediaId);
  }

  /// Delete from a [CloudMediaItem] reference.
  static Future<void> deleteRef(CloudMediaItem item) => delete(item.id);

  /// Show a confirmation dialog then delete if confirmed.
  ///
  /// Returns `true` if the user confirmed and the delete call succeeded,
  /// `false` if the user cancelled the dialog. If the user confirms but
  /// the delete itself fails (network error, permission issue, etc.),
  /// this rethrows that exception rather than returning `false` —
  /// swallowing a real failure into the same boolean as "user cancelled"
  /// would hide it from the caller. Wrap the call in your own
  /// try/catch if you want to show your own error UI for that case:
  ///
  /// ```dart
  /// try {
  ///   final deleted = await CloudMedia.showDeleteDialog(context, item);
  ///   if (deleted) { /* removed from your own list, etc. */ }
  /// } catch (e) {
  ///   // deletion was confirmed but failed
  /// }
  /// ```
  static Future<bool> showDeleteDialog(
    BuildContext context,
    CloudMediaItem item,
  ) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete media?',
      message: '"${item.fileName}" will be permanently removed.',
      confirmText: 'Delete',
      confirmColor: Colors.red,
    );
    if (confirmed != true) return false;
    await delete(item.id);
    return true;
  }

  /// Download to local storage. Checks cache first.
  static Future<String> download(String mediaId) async {
    _ensure();
    return _provider!.downloadMedia(mediaId);
  }

  /// Share via platform share sheet.
  static Future<void> share(String mediaId) async {
    _ensure();
    await _provider!.shareMedia(mediaId);
  }

  /// Restore a soft-deleted item.
  static Future<void> restore(String mediaId) async {
    _ensure();
    await _provider!.restoreMedia(mediaId);
  }

  /// Force-flush the offline sync queue.
  static Future<void> sync() async {
    _ensure();
    await _provider!.forceSync();
  }

  /// Number of operations pending in the offline queue.
  static Future<int> getPendingCount() async {
    _ensure();
    return _provider!.getPendingCount();
  }

  /// Live upload progress for [mediaId]. Emits until the upload completes
  /// or fails, then the stream closes.
  ///
  /// ```dart
  /// CloudMedia.watchUploadProgress(item.id).listen((p) {
  ///   print('${(p.progress * 100).toStringAsFixed(0)}%');
  /// });
  /// ```
  static Stream<UploadProgressData> watchUploadProgress(String mediaId) {
    _ensure();
    return _provider!.watchUploadProgress(mediaId);
  }

  /// Pause an in-flight upload. No-op if [mediaId] isn't currently uploading.
  static void pauseUpload(String mediaId) {
    _ensure();
    _provider!.pauseUpload(mediaId);
  }

  /// Resume a paused upload. No-op if [mediaId] isn't currently uploading.
  static void resumeUpload(String mediaId) {
    _ensure();
    _provider!.resumeUpload(mediaId);
  }

  /// Cancel an in-flight upload. No-op if [mediaId] isn't currently uploading.
  static void cancelUpload(String mediaId) {
    _ensure();
    _provider!.cancelUpload(mediaId);
  }

  /// True while [mediaId]'s upload is actively talking to Firebase Storage.
  static bool isUploading(String mediaId) {
    _ensure();
    return _provider!.isUploading(mediaId);
  }

  /// Clear all local disk cache.
  ///
  /// ```dart
  /// await CloudMedia.clearCache();
  /// ```
  static Future<void> clearCache() async {
    _ensure();
    await _provider!.clearCache();
  }

  /// Returns total cache size in bytes.
  ///
  /// ```dart
  /// final bytes = await CloudMedia.cacheSize();
  /// final mb = (bytes / 1024 / 1024).toStringAsFixed(1);
  /// print('Cache: ${mb}MB');
  /// ```
  static Future<int> cacheSize() async {
    _ensure();
    return _provider!.getCacheSize();
  }

  /// Cancels all active [watchMedia]/[watchUploadProgress] subscriptions
  /// and closes the local cache's underlying storage.
  ///
  /// Call this if your app needs a clean shutdown (e.g. before the user
  /// signs out, or when a test tears down its own `CloudMedia` instance)
  /// — otherwise `CloudMedia` is designed to live for the app's whole
  /// lifetime and this never needs to be called. After calling this,
  /// [initialize] must be called again before using `CloudMedia` further.
  ///
  /// ```dart
  /// await CloudMedia.dispose();
  /// ```
  static Future<void> dispose() async {
    if (_provider == null) return;
    await _provider!.dispose();
    _provider = null;
    _initialized = false;
  }

  static void _ensure() {
    if (!_initialized || _provider == null) {
      throw StateError(
          'CloudMedia not initialized. Call CloudMedia.initialize() first.');
    }
  }
}
