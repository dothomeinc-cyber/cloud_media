import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import '../constants/file_constants.dart';

class FileUtils {
  FileUtils._();

  static String getFileExtension(String fileName) =>
      path.extension(fileName).toLowerCase().replaceFirst('.', '');

  static String getFileNameWithoutExtension(String fileName) =>
      path.basenameWithoutExtension(fileName);

  static String getMimeType(String fileName) =>
      lookupMimeType(fileName) ?? 'application/octet-stream';

  // Deferring to FileConstants (the same lists CloudMediaType.
  // acceptedExtensions and Validators.validateFileType use) rather than
  // duplicating the extension lists here a third time — previously
  // these were hardcoded separately and could silently drift out of
  // sync with the canonical lists if either was updated alone.
  static bool isImage(String fileName) =>
      FileConstants.imageExtensions.contains(getFileExtension(fileName));

  static bool isVideo(String fileName) =>
      FileConstants.videoExtensions.contains(getFileExtension(fileName));

  static bool isAudio(String fileName) =>
      FileConstants.audioExtensions.contains(getFileExtension(fileName));

  static bool isPdf(String fileName) =>
      getFileExtension(fileName) == 'pdf';

  static Future<int> getFileSize(File file) => file.length();

  static Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) await file.delete();
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
