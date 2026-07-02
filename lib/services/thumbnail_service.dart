import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_video_thumbnail_plus/flutter_video_thumbnail_plus.dart';
import '../models/cloud_media_config.dart';
import '../models/cloud_media_type.dart';
import '../utils/logger.dart';
//import 'package:flutter_video_thumbnail_plus/flutter_video_thumbnail_plus.dart';

class ThumbnailService {
  ThumbnailService({required this.config});

  final CloudMediaConfig config;

  Future<String?> generateThumbnail(
    String filePath,
    CloudMediaType type, {
    int? size,
  }) async {
    try {
      final targetSize = size ?? config.thumbnailSize;
      switch (type) {
        case CloudMediaType.image:
          return _imageThumbnail(filePath, targetSize);
        case CloudMediaType.video:
          return _videoThumbnail(filePath, targetSize);
        default:
          return null;
      }
    } catch (e, st) {
      CloudLogger.error('Thumbnail generation failed',
          error: e, stackTrace: st);
      return null;
    }
  }

  Future<String?> _imageThumbnail(
      String filePath, int size) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return null;

    final thumb =
        img.copyResizeCropSquare(image, size: size);

    final tempDir = await getTemporaryDirectory();
    final thumbPath =
        '${tempDir.path}/cm_thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final thumbBytes = img.encodeJpg(thumb, quality: 80);
    await File(thumbPath).writeAsBytes(thumbBytes);

    CloudLogger.debug('Image thumbnail: $thumbPath');
    return thumbPath;
  }

  Future<String?> _videoThumbnail(
      String filePath, int size) async {
    try {
      final tempDir = await getTemporaryDirectory();

      final thumbPath =
          await FlutterVideoThumbnailPlus.thumbnailFile(
        video: filePath,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.webp,
        maxWidth: size,
        maxHeight: size,
        timeMs: 1000,
        quality: 80,
      );

      if (thumbPath == null) {
        CloudLogger.warning(
            'Video thumbnail returned null: $filePath');
        return null;
      }

      CloudLogger.debug('Video thumbnail: $thumbPath');
      return thumbPath;
    } catch (e, st) {
      CloudLogger.error('Video thumbnail failed',
          error: e, stackTrace: st);
      return null;
    }
  }

  Future<Uint8List?> generateThumbnailBytes(
      Uint8List bytes, int size) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return null;
      final thumb =
          img.copyResizeCropSquare(image, size: size);
      return Uint8List.fromList(
          img.encodeJpg(thumb, quality: 80));
    } catch (e) {
      CloudLogger.error('Thumbnail bytes failed', error: e);
      return null;
    }
  }
}
