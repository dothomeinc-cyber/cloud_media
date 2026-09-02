import '../constants/file_constants.dart';
import '../models/cloud_media_type.dart';
import '../utils/error_handler.dart';
import '../utils/file_utils.dart';

class Validators {
  Validators._();

  static void validateFileType(String fileName) {
    final ext = FileUtils.getFileExtension(fileName).toLowerCase();
    final all = [
      ...FileConstants.imageExtensions,
      ...FileConstants.videoExtensions,
      ...FileConstants.audioExtensions,
      ...FileConstants.documentExtensions,
    ];
    if (!all.contains(ext)) {
      throw CloudMediaUnsupportedFileTypeException(
          'File type ".$ext" is not supported.');
    }
  }

  static void validateFileSize(int bytes, CloudMediaType type) {
    final int limit;
    switch (type) {
      case CloudMediaType.image:
        limit = FileConstants.maxImageSizeBytes;
        break;
      case CloudMediaType.video:
        limit = FileConstants.maxVideoSizeBytes;
        break;
      case CloudMediaType.audio:
        limit = FileConstants.maxAudioSizeBytes;
        break;
      case CloudMediaType.file:
        limit = FileConstants.maxDocumentSizeBytes;
        break;
    }
    if (bytes > limit) {
      throw CloudMediaFileTooLargeException(
          'File ${FileUtils.formatFileSize(bytes)} exceeds '
          '${FileUtils.formatFileSize(limit)} limit.');
    }
  }

  static void validateSelectionCount(int count, {int? maxAllowed}) {
    if (count > FileConstants.hardMaxSelection) {
      // Built from the real constant rather than relying on
      // CloudMediaSelectionLimitExceededException's const default
      // (which has to hardcode a literal, since Dart's const defaults
      // can't interpolate — see that class's own doc comment) — this
      // throw site can pass the real number directly instead.
      throw CloudMediaSelectionLimitExceededException(
          'Selection limit exceeded. Maximum is '
          '${FileConstants.hardMaxSelection} files.');
    }
    final limit = maxAllowed ?? FileConstants.defaultMaxSelection;
    if (count > limit) {
      throw CloudMediaSelectionLimitExceededException(
          'Selected $count files exceeds maximum of $limit.');
    }
  }

  static bool isValidUrl(String url) {
    final r = RegExp(
        r'^(http|https)://[\w-]+(\.[\w-]+)+([\w.,@?^=%&:/~+#-]*[\w@?^=%&/~+#-])?$');
    return r.hasMatch(url);
  }

  static bool isValidFileName(String fileName) =>
      !RegExp(r'[<>:"/\\|?*]').hasMatch(fileName);
}
