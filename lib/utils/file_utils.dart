import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';

class FileUtils {
  FileUtils._();

  static String getFileExtension(String fileName) =>
      path.extension(fileName).toLowerCase().replaceFirst('.', '');

  static String getFileNameWithoutExtension(String fileName) =>
      path.basenameWithoutExtension(fileName);

  static String getMimeType(String fileName) =>
      lookupMimeType(fileName) ?? 'application/octet-stream';

  static bool isImage(String fileName) =>
      ['jpg', 'jpeg', 'png', 'webp'].contains(getFileExtension(fileName));

  static bool isVideo(String fileName) =>
      ['mp4', 'mov'].contains(getFileExtension(fileName));

  static bool isAudio(String fileName) =>
      ['mp3', 'aac', 'm4a'].contains(getFileExtension(fileName));

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
