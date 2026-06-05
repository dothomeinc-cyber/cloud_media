class FileConstants {
  FileConstants._();

  static const String cacheBoxName = 'cloud_media_cache';
  static const String uploadsBoxName = 'cloud_media_uploads';
  static const String cacheDirectory = 'cloud_media_cache';
  static const String thumbnailsDirectory = 'thumbnails';

  static const List<String> imageExtensions = ['jpg', 'jpeg', 'png', 'webp'];
  static const List<String> videoExtensions = ['mp4', 'mov'];
  static const List<String> audioExtensions = ['mp3', 'aac', 'm4a'];
  static const List<String> documentExtensions = ['pdf'];

  static const int maxImageSizeBytes = 10 * 1024 * 1024;
  static const int maxVideoSizeBytes = 100 * 1024 * 1024;
  static const int maxAudioSizeBytes = 50 * 1024 * 1024;
  static const int maxDocumentSizeBytes = 25 * 1024 * 1024;

  static const int maxCacheAgeDays = 30;
  static const int maxCacheSizeBytes = 500 * 1024 * 1024;

  static const int defaultMaxSelection = 20;
  static const int hardMaxSelection = 100;
}
