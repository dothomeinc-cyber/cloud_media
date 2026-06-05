class CloudMediaConfig {
  final int maxCacheSizeMb;
  final int imageQuality;
  final int thumbnailSize;
  final int maxSelection;
  final bool enableOfflineSync;
  final bool enableReviewScreen;
  final bool enableBackgroundRemoval;
  final Duration uploadTimeout;
  final int maxRetries;
  final bool autoGenerateThumbnails;
  final bool compressAutomatically;
  final bool enableVideoCompression;
  final int videoCompressionBitrate;
  final bool enableLogging;
  final String? customStorageBucket;

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
