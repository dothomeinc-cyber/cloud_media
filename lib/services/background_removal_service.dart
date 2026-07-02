import 'dart:io';
import 'dart:typed_data';
import 'package:native_cutout/native_cutout.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/logger.dart';

/// On-device background removal using native_cutout.
///
/// Android uses Google ML Kit Subject Segmentation. iOS uses Vision and needs
/// iOS 17+ on a real device. Output is always a transparent PNG.
class BackgroundRemovalService {
  const BackgroundRemovalService();

  Future<String> removeBackground(
    String imagePath, {
    bool cropToSubject = true,
  }) async {
    if (imagePath.trim().isEmpty || !File(imagePath).existsSync()) {
      return imagePath;
    }

    try {
      final result = await NativeCutout.removeBackground(
        imagePath,
        options: CutoutOptions(
          cropToSubject: cropToSubject,
          writeToCache: true,
        ),
      );

      if (result is CutoutFileSuccess) return result.path;

      if (result is CutoutBytesSuccess) {
        return _writeBytesToTemp(result.pngBytes);
      }

      if (result is CutoutFailure) {
        CloudLogger.warning(
          'Background removal failed: ${result.code.name} - ${result.message}',
        );
      }
    } catch (e, st) {
      CloudLogger.error(
        'Background removal failed',
        error: e,
        stackTrace: st,
      );
    }

    return imagePath;
  }

  Future<bool> isModelAvailable() => NativeCutout.isModelAvailable();

  Future<bool> downloadModel() => NativeCutout.downloadModel();

  Future<bool> clearModel() => NativeCutout.clearModel();

  Future<bool> clearCache() => NativeCutout.clearCache();

  Stream<ModelDownloadProgress> get downloadProgress =>
      NativeCutout.downloadProgress;

  Future<String> _writeBytesToTemp(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/cm_bg_removed_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}
