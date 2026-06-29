import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/file_constants.dart';
import '../models/cloud_media_config.dart';
import '../models/cloud_media_type.dart';
import '../utils/error_handler.dart';
import '../utils/logger.dart';
import '../utils/validators.dart';

class UploadService {
  UploadService({required this.config});

  final CloudMediaConfig config;
  final ImagePicker _imagePicker = ImagePicker();
  final Map<String, StreamController<UploadProgressData>> _progressControllers = {};
  final Map<String, CancelToken> _cancelTokens = {};

  Future<List<PickedFile>> pickMedia({
    required CloudMediaType type,
    required int maxCount,
  }) async {
    if (maxCount > FileConstants.hardMaxSelection) {
      throw CloudMediaSelectionLimitExceededException(
          'Requested $maxCount exceeds hard limit of ${FileConstants.hardMaxSelection}.');
    }

    List<PickedFile> pickedFiles = [];

    switch (type) {
      case CloudMediaType.image:
        final files = await _imagePicker.pickMultiImage(
          limit: maxCount,
          imageQuality: 100,
        );
        pickedFiles = files.map((f) => PickedFile(f.path)).toList();
        break;

      case CloudMediaType.video:
        // image_picker only supports single video selection.
        // maxCount > 1 is silently treated as 1 for video — this is a known
        // platform limitation. Use CloudMediaType.file for multi-video picking.
        if (maxCount > 1) {
          CloudLogger.warning(
              'Video picking supports maxCount=1 only (platform limitation). '
              'Requested $maxCount — picking 1.');
        }
        final file = await _imagePicker.pickVideo(source: ImageSource.gallery);
        if (file != null) {
          pickedFiles = [PickedFile(file.path)];
        }
        break;

      case CloudMediaType.audio:
        // file_picker 12.x: fully static, use pickFile for single, pickFiles for multiple
        if (maxCount == 1) {
          final result = await FilePicker.pickFile(type: FileType.audio);
          if (result != null) pickedFiles = [PickedFile(result.path!)];
        } else {
          final result = await FilePicker.pickFiles(type: FileType.audio);
          if (result != null) {
            pickedFiles = result.paths.whereType<String>().map(PickedFile.new).toList();
          }
        }
        break;

      case CloudMediaType.file:
        if (maxCount == 1) {
          final result = await FilePicker.pickFile(
            type: FileType.custom,
            allowedExtensions: ['pdf'],
          );
          if (result != null) pickedFiles = [PickedFile(result.path!)];
        } else {
          final result = await FilePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['pdf'],
          );
          if (result != null) {
            pickedFiles = result.paths.whereType<String>().map(PickedFile.new).toList();
          }
        }
        break;
    }

    for (final file in pickedFiles) {
      Validators.validateFileType(file.name);
      final size = await file.length();
      Validators.validateFileSize(size, type);
    }

    CloudLogger.info('Picked ${pickedFiles.length} ${type.displayName}(s)');
    return pickedFiles;
  }

  Stream<UploadProgressData> getUploadProgress(String uploadId) {
    _progressControllers.putIfAbsent(
        uploadId, () => StreamController<UploadProgressData>.broadcast());
    return _progressControllers[uploadId]!.stream;
  }

  void updateProgress(String uploadId, double progress, int uploaded, int total) {
    _progressControllers[uploadId]?.add(
      UploadProgressData(progress: progress, uploaded: uploaded, total: total),
    );
  }

  void completeUpload(String uploadId) {
    _progressControllers[uploadId]?.add(const UploadProgressData(
        progress: 1.0, uploaded: 100, total: 100, status: 'completed'));
  }

  void failUpload(String uploadId) {
    _progressControllers[uploadId]?.add(const UploadProgressData(
        progress: 0, uploaded: 0, total: 0, status: 'failed'));
  }

  void cancelUpload(String uploadId) {
    _cancelTokens[uploadId]?.cancel();
    _cancelTokens.remove(uploadId);
    _progressControllers[uploadId]?.close();
    _progressControllers.remove(uploadId);
  }

  CancelToken createCancelToken(String uploadId) {
    final token = CancelToken();
    _cancelTokens[uploadId] = token;
    return token;
  }

  bool isCancelled(String uploadId) =>
      _cancelTokens[uploadId]?.isCancelled ?? false;

  void dispose() {
    for (final c in _progressControllers.values) { c.close(); }
    _progressControllers.clear();
    _cancelTokens.clear();
  }
}

class PickedFile {
  PickedFile(this.path)
      : name = path.split('/').last,
        mimeType = _mimeType(path);

  final String path;
  final String name;
  final String mimeType;

  Future<int> length() => File(path).length();

  static String _mimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'webp': return 'image/webp';
      case 'mp4': return 'video/mp4';
      case 'mov': return 'video/quicktime';
      case 'mp3': return 'audio/mpeg';
      case 'aac': return 'audio/aac';
      case 'm4a': return 'audio/m4a';
      case 'pdf': return 'application/pdf';
      default: return 'application/octet-stream';
    }
  }
}

class UploadProgressData {
  const UploadProgressData({
    required this.progress,
    required this.uploaded,
    required this.total,
    this.status = 'uploading',
  });
  final double progress;
  final int uploaded;
  final int total;
  final String status;
}

class CancelToken {
  bool _isCancelled = false;
  void cancel() => _isCancelled = true;
  bool get isCancelled => _isCancelled;
}
