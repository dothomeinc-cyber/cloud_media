import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../models/cloud_media_config.dart';
import '../models/cloud_media_type.dart';
import '../utils/logger.dart';

class ThumbnailService {
  ThumbnailService({required this.config});

  final CloudMediaConfig config;

  /// Generate a 200×200 WebP thumbnail on-device (no Cloud Functions).
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
          CloudLogger.debug('Video thumbnail not yet implemented');
          return null;
        default:
          return null;
      }
    } catch (e, st) {
      CloudLogger.error('Thumbnail generation failed', error: e, stackTrace: st);
      return null;
    }
  }

  Future<String?> _imageThumbnail(String filePath, int size) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return null;

    final thumb = img.copyResize(image,
        width: size, height: size, interpolation: img.Interpolation.linear);

    final tempDir = await getTemporaryDirectory();
    final thumbPath =
        '${tempDir.path}/cm_thumb_${DateTime.now().millisecondsSinceEpoch}.webp';

    // WebP quality 80 per spec
    final thumbBytes = img.encodeNamedImage(thumbPath, thumb) ??
        img.encodeJpg(thumb, quality: 80);
    await File(thumbPath).writeAsBytes(thumbBytes);

    CloudLogger.debug('Thumbnail: $thumbPath');
    return thumbPath;
  }

  Future<Uint8List?> generateThumbnailBytes(Uint8List bytes, int size) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return null;
      final thumb = img.copyResize(image, width: size, height: size);
      return Uint8List.fromList(img.encodeJpg(thumb, quality: 80));
    } catch (e) {
      CloudLogger.error('Thumbnail bytes failed', error: e);
      return null;
    }
  }
}
