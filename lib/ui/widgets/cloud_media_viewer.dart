import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/cloud_media_item.dart';
import '../../models/cloud_media_type.dart';
import 'cloud_audio.dart';
import 'cloud_file.dart';
import 'cloud_image.dart';
import 'cloud_video.dart';

/// Single widget that handles displaying any [CloudMediaItem] type —
/// image, video, audio, PDF, and generic files — automatically picking
/// the right renderer based on [CloudMediaItem.type].
///
/// ```dart
/// CloudMediaViewer(media: item)
/// CloudMediaViewer(media: item, autoPlay: false)
/// CloudMediaViewer(media: item, showControls: true)
/// ```
class CloudMediaViewer extends StatelessWidget {
  const CloudMediaViewer({
    super.key,
    required this.media,
    this.width,
    this.height,
    this.fit = BoxFit.cover,

    /// Images — enable pinch-to-zoom fullscreen overlay
    this.enableZoom = false,

    /// Videos — start playing immediately when mounted
    this.autoPlay = false,

    /// Videos & audio — show playback controls
    this.showControls = true,

    /// Files — called when the user taps the download button
    this.onDownload,
  });

  final CloudMediaItem media;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool enableZoom;
  final bool autoPlay;
  final bool showControls;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    return switch (media.type) {
      CloudMediaType.image => CloudImage(
          media: media,
          width: width,
          height: height,
          fit: fit,
          enableZoom: enableZoom,
        ),
      CloudMediaType.video => CloudVideo(
          media: media,
          width: width,
          height: height,
          autoPlay: autoPlay,
          showControls: showControls,
        ),
      CloudMediaType.audio => CloudAudio(
          media: media,
        ),
      CloudMediaType.file => CloudFile(
          media: media,
          onDownload: onDownload,
        ),
    };
  }
}

/// Compact thumbnail variant of [CloudMediaViewer] — used in grids and lists.
/// Shows a representative visual for every type without full controls.
class CloudMediaThumbnail extends StatelessWidget {
  const CloudMediaThumbnail({
    super.key,
    required this.media,
    this.size = 80,
    this.borderRadius,
    this.onTap,
  });

  final CloudMediaItem media;
  final double size;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(8.r);
    final icon = _iconFor(media.type);

    Widget content;

    if (media.type == CloudMediaType.image) {
      content = CloudImage(
        media: media,
        width: size.w,
        height: size.w,
        fit: BoxFit.cover,
      );
    } else {
      content = Container(
        width: size.w,
        height: size.w,
        color: const Color(0xFFF5F5F5),
        child: Icon(icon, size: (size * 0.4).sp, color: Colors.black54),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(borderRadius: radius, child: content),
    );
  }

  IconData _iconFor(CloudMediaType type) => switch (type) {
    CloudMediaType.image => Icons.image_outlined,
    CloudMediaType.video => Icons.play_circle_outline,
    CloudMediaType.audio => Icons.audiotrack_outlined,
    CloudMediaType.file  => Icons.insert_drive_file_outlined,
  };
}
