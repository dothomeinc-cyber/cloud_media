/// Configuration for the CloudMedia package.
///
/// Pass to [CloudMedia.initialize] to customize behavior:
/// ```dart
/// await CloudMedia.initialize(
///   config: const CloudMediaConfig(
///     imageQuality: 85,
///     maxSelection: 20,
///     enableOfflineSync: true,
///   ),
/// );
/// ```
class CloudMediaConfig {
  /// Maximum disk cache size in megabytes. Default: 500.
  final int maxCacheSizeMb;

  /// Image compression quality (1–100). Default: 85.
  /// Images are compressed to WebP at this quality level.
  final int imageQuality;

  /// Thumbnail size in pixels (width and height). Default: 200.
  /// Thumbnails are generated as 200×200 WebP on-device.
  final int thumbnailSize;

  /// Maximum number of files the user can select at once. Default: 20.
  /// Hard maximum is 100.
  final int maxSelection;

  /// Whether to enable offline-first sync via riverpod_offline_sync. Default: true.
  final bool enableOfflineSync;

  /// Whether to show a review screen after picking media. Default: true.
  final bool enableReviewScreen;

  /// Whether background removal is available in the pick flow. Default: true.
  final bool enableBackgroundRemoval;

  /// Timeout for individual upload operations. Default: 5 minutes.
  final Duration uploadTimeout;

  /// Maximum number of upload retries on failure. Default: 3.
  final int maxRetries;

  /// Whether to automatically generate thumbnails after picking. Default: true.
  final bool autoGenerateThumbnails;

  /// Whether to automatically compress images to WebP after picking. Default: true.
  final bool compressAutomatically;

  /// Whether video compression is enabled. Default: false (pass-through).
  final bool enableVideoCompression;

  /// Target bitrate for video compression in bits per second. Default: 1Mbps.
  final int videoCompressionBitrate;

  /// Whether to print debug logs. Default: false.
  final bool enableLogging;

  /// Optional custom Firebase Storage bucket URL.
  /// If null, uses the default Firebase Storage bucket.
  final String? customStorageBucket;

  /// Creates a [CloudMediaConfig] with the given settings.
  ///
  /// All parameters have sensible defaults and are optional.
  const CloudMediaConfig({
    this.maxCacheSizeMb = 500,
    this.imageQuality = 85,
    this.thumbnailSize = 200,
    this.maxSelection = 20,
    this.enableOfflineSync = true,
    this.enableReviewScreen = true,
    this.enableBackgroundRemoval = true,
    this.uploadTimeout = const Duration(minutes: 5),
    this.maxRetries = 3,
    this.autoGenerateThumbnails = true,
    this.compressAutomatically = true,
    this.enableVideoCompression = false,
    this.videoCompressionBitrate = 1000000,
    this.enableLogging = false,
    this.customStorageBucket,
  });

  /// Creates a copy of this config with the given fields replaced.
  CloudMediaConfig copyWith({
    int? maxCacheSizeMb,
    int? imageQuality,
    int? thumbnailSize,
    int? maxSelection,
    bool? enableOfflineSync,
    bool? enableReviewScreen,
    bool? enableBackgroundRemoval,
    Duration? uploadTimeout,
    int? maxRetries,
    bool? autoGenerateThumbnails,
    bool? compressAutomatically,
    bool? enableVideoCompression,
    int? videoCompressionBitrate,
    bool? enableLogging,
    String? customStorageBucket,
  }) {
    return CloudMediaConfig(
      maxCacheSizeMb: maxCacheSizeMb ?? this.maxCacheSizeMb,
      imageQuality: imageQuality ?? this.imageQuality,
      thumbnailSize: thumbnailSize ?? this.thumbnailSize,
      maxSelection: maxSelection ?? this.maxSelection,
      enableOfflineSync: enableOfflineSync ?? this.enableOfflineSync,
      enableReviewScreen: enableReviewScreen ?? this.enableReviewScreen,
      enableBackgroundRemoval:
          enableBackgroundRemoval ?? this.enableBackgroundRemoval,
      uploadTimeout: uploadTimeout ?? this.uploadTimeout,
      maxRetries: maxRetries ?? this.maxRetries,
      autoGenerateThumbnails:
          autoGenerateThumbnails ?? this.autoGenerateThumbnails,
      compressAutomatically:
          compressAutomatically ?? this.compressAutomatically,
      enableVideoCompression:
          enableVideoCompression ?? this.enableVideoCompression,
      videoCompressionBitrate:
          videoCompressionBitrate ?? this.videoCompressionBitrate,
      enableLogging: enableLogging ?? this.enableLogging,
      customStorageBucket: customStorageBucket ?? this.customStorageBucket,
    );
  }

  /// Serializes this config to a JSON map.
  Map<String, dynamic> toJson() => {
        'maxCacheSizeMb': maxCacheSizeMb,
        'imageQuality': imageQuality,
        'thumbnailSize': thumbnailSize,
        'maxSelection': maxSelection,
        'enableOfflineSync': enableOfflineSync,
        'enableReviewScreen': enableReviewScreen,
        'enableBackgroundRemoval': enableBackgroundRemoval,
        'uploadTimeoutMs': uploadTimeout.inMilliseconds,
        'maxRetries': maxRetries,
        'autoGenerateThumbnails': autoGenerateThumbnails,
        'compressAutomatically': compressAutomatically,
        'enableVideoCompression': enableVideoCompression,
        'videoCompressionBitrate': videoCompressionBitrate,
        'enableLogging': enableLogging,
      };
}
