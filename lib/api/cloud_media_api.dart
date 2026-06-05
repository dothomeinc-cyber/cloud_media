import '../models/cloud_media_config.dart';
import '../models/cloud_media_item.dart';
import '../models/cloud_media_type.dart';
import '../providers/cloud_media_provider.dart';

/// The primary public API for CloudMedia.
///
/// ```dart
/// await CloudMedia.initialize(config: CloudMediaConfig());
/// final items = await CloudMedia.pick();
/// CloudImage(items.first.ref);
/// ```
class CloudMedia {
  CloudMedia._();

  static CloudMediaProvider? _provider;
  static CloudMediaConfig _config = const CloudMediaConfig();
  static bool _initialized = false;

  static Future<void> initialize({
    CloudMediaConfig config = const CloudMediaConfig(),
  }) async {
    _config = config;
    _provider = CloudMediaProvider(config: _config);
    await _provider!.initialize();
    _initialized = true;
  }

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

  static Stream<CloudMediaItem> watch(String mediaId) {
    _ensure();
    return _provider!.watchMedia(mediaId);
  }

  static Future<CloudMediaItem> get(String mediaId) async {
    _ensure();
    return _provider!.getMedia(mediaId);
  }

  static Future<void> delete(String mediaId) async {
    _ensure();
    await _provider!.deleteMedia(mediaId);
  }

  static Future<void> deleteRef(CloudMediaItem item) async {
    _ensure();
    await _provider!.deleteMedia(item.id);
  }

  static Future<String> download(String mediaId) async {
    _ensure();
    return _provider!.downloadMedia(mediaId);
  }

  static Future<void> share(String mediaId) async {
    _ensure();
    await _provider!.shareMedia(mediaId);
  }

  static Future<void> restore(String mediaId) async {
    _ensure();
    await _provider!.restoreMedia(mediaId);
  }

  static Future<void> sync() async {
    _ensure();
    await _provider!.forceSync();
  }

  static Future<int> getPendingCount() async {
    _ensure();
    return _provider!.getPendingCount();
  }

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
