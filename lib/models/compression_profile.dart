/// Preset compression profiles for common use-cases.
///
/// Pass to [CloudMedia.pick] as [compressionProfile]:
/// ```dart
/// await CloudMedia.pick(compressionProfile: CompressionProfile.product)
/// ```
enum CompressionProfile {
  /// High quality — suitable for hero images or anything shown large.
  /// Quality: 90, thumbnail: 400px.
  high,

  /// Balanced for product catalog images — good visual quality, reasonable size.
  /// Quality: 85 (package default), thumbnail: 300px.
  product,

  /// Optimised for profile pictures / avatars shown small.
  /// Quality: 75, thumbnail: 150px.
  avatar,

  /// Aggressive compression for thumbnails, previews, or low-bandwidth contexts.
  /// Quality: 60, thumbnail: 100px.
  thumbnail,

  /// No compression — pass the file through as-is.
  /// Use sparingly; large files may exceed Firestore Storage limits.
  none;

  /// The image quality value (1–100) for this profile.
  int get imageQuality => switch (this) {
    CompressionProfile.high      => 90,
    CompressionProfile.product   => 85,
    CompressionProfile.avatar    => 75,
    CompressionProfile.thumbnail => 60,
    CompressionProfile.none      => 100,
  };

  /// The thumbnail dimension in pixels for this profile.
  int get thumbnailSize => switch (this) {
    CompressionProfile.high      => 400,
    CompressionProfile.product   => 300,
    CompressionProfile.avatar    => 150,
    CompressionProfile.thumbnail => 100,
    CompressionProfile.none      => 200,
  };

  /// Whether automatic compression should run at all for this profile.
  bool get compress => this != CompressionProfile.none;
}
