import 'package:flutter/material.dart';

/// The type of media managed by CloudMedia.
enum CloudMediaType {
  /// JPEG, PNG, or WebP images (max 10MB).
  image,

  /// MP4 or MOV videos (max 100MB).
  video,

  /// MP3, AAC, or M4A audio files (max 50MB).
  audio,

  /// PDF documents (max 25MB).
  file,
}

/// Extension methods on [CloudMediaType].
extension CloudMediaTypeExtension on CloudMediaType {
  /// The Firestore string representation of this type.
  String get string {
    switch (this) {
      case CloudMediaType.image:
        return 'image';
      case CloudMediaType.video:
        return 'video';
      case CloudMediaType.audio:
        return 'audio';
      case CloudMediaType.file:
        return 'file';
    }
  }

  /// Human-readable display name.
  String get displayName {
    switch (this) {
      case CloudMediaType.image:
        return 'Image';
      case CloudMediaType.video:
        return 'Video';
      case CloudMediaType.audio:
        return 'Audio';
      case CloudMediaType.file:
        return 'File';
    }
  }

  /// Icon representing this media type.
  IconData get icon {
    switch (this) {
      case CloudMediaType.image:
        return Icons.image;
      case CloudMediaType.video:
        return Icons.videocam;
      case CloudMediaType.audio:
        return Icons.audiotrack;
      case CloudMediaType.file:
        return Icons.insert_drive_file;
    }
  }

  /// Accepted file extensions for this type.
  List<String> get acceptedExtensions {
    switch (this) {
      case CloudMediaType.image:
        return ['jpg', 'jpeg', 'png', 'webp'];
      case CloudMediaType.video:
        return ['mp4', 'mov'];
      case CloudMediaType.audio:
        return ['mp3', 'aac', 'm4a'];
      case CloudMediaType.file:
        return ['pdf'];
    }
  }

  /// MIME type prefix for this media type.
  String get mimeTypePrefix {
    switch (this) {
      case CloudMediaType.image:
        return 'image/';
      case CloudMediaType.video:
        return 'video/';
      case CloudMediaType.audio:
        return 'audio/';
      case CloudMediaType.file:
        return 'application/';
    }
  }
}
