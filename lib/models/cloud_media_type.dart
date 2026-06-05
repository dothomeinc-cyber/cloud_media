import 'package:flutter/material.dart';

enum CloudMediaType { image, video, audio, file }

extension CloudMediaTypeExtension on CloudMediaType {
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
