import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../models/cloud_media_config.dart';
import '../utils/error_handler.dart';
import '../utils/logger.dart';

class CompressionService {
  CompressionService({required this.config});

  final CloudMediaConfig config;

  /// Compress image to WebP (spec: quality 85, 40–80% reduction).
  /// Returns compressed path, or original if compression fails.
  ///
  /// Throws [CloudMediaCompressionException] if [filePath] doesn't exist
  /// at all — returning it unchanged in that case (as the "compression
  /// failed, use the original" fallback does) would hand the caller a
  /// path that was never valid to begin with, which would only surface
  /// much later and more confusingly, at the Firebase upload stage.
  Future<String> compressImage(String filePath,
      {int? quality}) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw CloudMediaCompressionException(
          'Cannot compress: file does not exist at $filePath');
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath =
          '${tempDir.path}/cm_${DateTime.now().millisecondsSinceEpoch}.webp';

      final result =
          await FlutterImageCompress.compressAndGetFile(
        filePath,
        targetPath,
        quality: quality ?? config.imageQuality,
        format: CompressFormat.webp,
      );

      if (result == null) {
        return filePath;
      }

      final orig = await file.length();
      final comp = await result.length();
      final pct =
          ((1 - comp / orig) * 100).toStringAsFixed(1);
      CloudLogger.debug(
          'Compressed: ${_fmt(orig)} → ${_fmt(comp)} ($pct% reduction)');

      return result.path;
    } catch (e, st) {
      CloudLogger.error(
          'Compression failed, using original',
          error: e,
          stackTrace: st);
      return filePath;
    }
  }

  /// Video: pass-through per spec (no transcoding in v1).
  Future<String> compressVideo(String filePath) async {
    CloudLogger.debug(
        'Video compression disabled; pass-through.');
    return filePath;
  }

  Future<String> compress(
      String filePath, String mimeType) async {
    if (mimeType.startsWith('image/')) {
      return compressImage(filePath);
    }
    return filePath;
  }

  String _fmt(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(1)} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
