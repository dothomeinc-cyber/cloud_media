import '../models/cloud_media_config.dart';
import '../models/cloud_media_item.dart';
import '../models/cloud_media_type.dart';
import '../providers/cloud_media_provider.dart';

/// The primary public API for the CloudMedia package.
///
/// Initialize once in `main()` before using any other methods:
/// ```dart
/// await CloudMedia.initialize(config: CloudMediaConfig());
/// ```
///
/// Then use anywhere in your app:
/// ```dart
/// final items = await CloudMedia.pick();
/// final all   = await CloudMedia.list();
/// CloudMedia.watch(items.first.id).listen((item) => print(item.status));
/// await CloudMedia.delete(items.first.id);
/// ```
class CloudMedia {
  CloudMedia._();

  static CloudMediaProvider? _provider;
  static CloudMediaConfig _config = const CloudMediaConfig();
  static bool _initialized = false;

  /// Initialize CloudMedia with the given [config].
  ///
  /// Must be called once before any other [CloudMedia] method.
  /// Firebase and riverpod_offline_sync must be initialized by the host app
  /// before calling this.
  ///
  /// ```dart
  /// await CloudMedia.initialize(
  ///   config: const CloudMediaConfig(
  ///     imageQuality: 85,
  ///     enableOfflineSync: true,
  ///   ),
  /// );
  /// ```
  static Future<void> initialize({
    CloudMediaConfig config = const CloudMediaConfig(),
  }) async {
    _config = config;
    _provider = CloudMediaProvider(config: _config);
    await _provider!.initialize();
    _initialized = true;
  }

  /// Pick one or more media files from the device.
  ///
  /// Returns a [List<CloudMediaItem>]. Each item is immediately available
  /// with a [localPath] while the upload queues in the background.
  ///
  /// Parameters:
  /// - [type] — the type of media to pick (default: [CloudMediaType.image])
  /// - [maxCount] — maximum number of files (default: 1, max: 100)
  /// - [enableEditing] — show crop/rotate editor after picking
  /// - [enableBackgroundRemoval] — show background removal screen
  ///
  /// ```dart
  /// // Single image
  /// final items = await CloudMedia.pick();
  ///
  /// // Multiple images
  /// final items = await CloudMedia.pick(maxCount: 10);
  ///
  /// // With background removal
  /// final items = await CloudMedia.pick(enableBackgroundRemoval: true);
  /// ```
  ///
  /// Throws [CloudMediaPermissionDeniedException] if permission is denied.
  /// Throws [CloudMediaFileTooLargeException] if a file exceeds the size limit.
  /// Throws [CloudMediaUnsupportedFileTypeException] for unsupported formats.
  static Future<List<CloudMediaItem>> pick({
    CloudMediaType type = CloudMediaType.image,
    int maxCount = 1,
    bool enableEditing = true,
    bool enableBackgroundRemoval = false,
  }) async {
    _ensure();
    return _provider!.pickMedia(
      type: type,
      maxCount: maxCount,
      enableEditing: enableEditing,
      enableBackgroundRemoval: enableBackgroundRemoval,
    );
  }

  /// List all media uploaded by the current authenticated user.
  ///
  /// Supports filtering by type, date range, and pagination.
  ///
  /// ```dart
  /// // All media
  /// final all = await CloudMedia.list();
  ///
  /// // Images only
  /// final images = await CloudMedia.list(type: CloudMediaType.image);
  ///
  /// // Date range
  /// final recent = await CloudMedia.list(
  ///   startDate: DateTime.now().subtract(Duration(days: 7)),
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

  /// Watch real-time status updates for a media item.
  ///
  /// Emits updates as the item transitions through:
  /// `pending → processing → syncing → synced`
  ///
  /// ```dart
  /// CloudMedia.watch(item.id).listen((updated) {
  ///   print(updated.status.displayName);
  ///   print(updated.downloadUrl); // available when synced
  /// });
  /// ```
  static Stream<CloudMediaItem> watch(String mediaId) {
    _ensure();
    return _provider!.watchMedia(mediaId);
  }

  /// Fetch a single media item by its [mediaId].
  ///
  /// Throws [CloudMediaNotFoundException] if the item does not exist.
  static Future<CloudMediaItem> get(String mediaId) async {
    _ensure();
    return _provider!.getMedia(mediaId);
  }

  /// Delete a media item by [mediaId].
  ///
  /// Removes the item from Firebase Storage, Firestore, and local cache.
  /// The deletion is queued if offline and executed when connectivity returns.
  static Future<void> delete(String mediaId) async {
    _ensure();
    await _provider!.deleteMedia(mediaId);
  }

  /// Delete a media item by its [CloudMediaItem] reference.
  static Future<void> deleteRef(CloudMediaItem item) async {
    _ensure();
    await _provider!.deleteMedia(item.id);
  }

  /// Download a media item to the device's local storage.
  ///
  /// Returns the local file path. Checks cache before downloading.
  static Future<String> download(String mediaId) async {
    _ensure();
    return _provider!.downloadMedia(mediaId);
  }

  /// Share a media item using the platform share sheet.
  static Future<void> share(String mediaId) async {
    _ensure();
    await _provider!.shareMedia(mediaId);
  }

  /// Restore a soft-deleted media item.
  static Future<void> restore(String mediaId) async {
    _ensure();
    await _provider!.restoreMedia(mediaId);
  }

  /// Force-flush all pending operations in the offline sync queue.
  static Future<void> sync() async {
    _ensure();
    await _provider!.forceSync();
  }

  /// Returns the number of operations currently waiting in the offline queue.
  static Future<int> getPendingCount() async {
    _ensure();
    return _provider!.getPendingCount();
  }

  /// Clear all local disk and memory cache.
  static Future<void> clearCache() async {
    _ensure();
    await _provider!.clearCache();
  }

  static void _ensure() {
    if (!_initialized || _provider == null) {
      throw StateError(
          'CloudMedia not initialized. Call CloudMedia.initialize() first.');
    }
  }
}
