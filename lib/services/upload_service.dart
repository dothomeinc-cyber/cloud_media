import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/file_constants.dart';
import '../models/cloud_media_config.dart';
import '../models/cloud_media_type.dart';
import '../utils/error_handler.dart';
import '../utils/logger.dart';
import '../utils/validators.dart';
import 'offline_sync_service.dart';

class UploadService {
  UploadService({required this.config});

  final CloudMediaConfig config;
  final ImagePicker _imagePicker = ImagePicker();

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
        if (maxCount == 1) {
          final f = await FilePicker.pickFile(type: FileType.audio);
          if (f?.path != null) pickedFiles = [PickedFile(f!.path!)];
        } else {
          // pickFiles() returns List<PlatformFile> directly (not a
          // FilePickerResult wrapper) as of file_picker v12 — an empty
          // list on cancellation, never null. Confirmed via a real
          // compiler error against the actually-installed version
          // (result.files / "The getter 'files' isn't defined for the
          // type 'List<PlatformFile>'").
          final result = await FilePicker.pickFiles(type: FileType.audio);
          pickedFiles = result
              .take(maxCount)
              .map((f) => f.path)
              .whereType<String>()
              .map(PickedFile.new)
              .toList();
        }
        break;

      case CloudMediaType.file:
        if (maxCount == 1) {
          final f = await FilePicker.pickFile(
            type: FileType.custom,
            allowedExtensions: ['pdf'],
          );
          if (f?.path != null) pickedFiles = [PickedFile(f!.path!)];
        } else {
          // See the audio case above for why this no longer checks
          // `result != null` — pickFiles() returns a non-nullable
          // List<PlatformFile> as of file_picker v12.
          final result = await FilePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['pdf'],
          );
          pickedFiles = result
              .take(maxCount)
              .map((f) => f.path)
              .whereType<String>()
              .map(PickedFile.new)
              .toList();
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

  /// Live progress for [mediaId]'s upload. Emits until the upload
  /// completes or fails, then the underlying stream closes.
  Stream<UploadProgressData> getUploadProgress(String mediaId) {
    return OfflineSyncService.watchUploadProgress(mediaId).map((p) {
      final status = p.isComplete
          ? 'completed'
          : p.isFailed
              ? 'failed'
              : 'uploading';
      return UploadProgressData(
        progress: p.fraction,
        uploaded: p.bytesTransferred,
        total: p.totalBytes,
        status: status,
      );
    });
  }

  // ── Pause / resume / cancel ─────────────────────────────────────────────
  //
  // These act directly on the underlying Firebase UploadTask for
  // [mediaId] via OfflineSyncService (backed by StorageQueue), so they
  // only take effect once the upload has actually started — see
  // OfflineSyncService's class doc for why file uploads sit behind both
  // the offline queue (for durability while offline/queued) and
  // StorageQueue (for live progress/pause/resume/cancel once in flight).

  /// Pause an in-flight upload. No-op if [mediaId] isn't currently uploading.
  void pauseUpload(String mediaId) => OfflineSyncService.pauseUpload(mediaId);

  /// Resume a paused upload. No-op if [mediaId] isn't currently uploading.
  void resumeUpload(String mediaId) => OfflineSyncService.resumeUpload(mediaId);

  /// Cancel an in-flight upload. No-op if [mediaId] isn't currently uploading.
  void cancelUpload(String mediaId) => OfflineSyncService.cancelUpload(mediaId);

  /// True while [mediaId]'s upload is actively in flight (i.e. past the
  /// offline queue and currently talking to Firebase Storage).
  bool isUploading(String mediaId) => OfflineSyncService.isUploading(mediaId);

  /// True if [mediaId]'s upload was cancelled via [cancelUpload].
  bool isCancelled(String mediaId) => OfflineSyncService.isUploadCancelled(mediaId);

  void dispose() {
    // Nothing to release here — StorageQueue (owned by OfflineSyncService,
    // a package-wide singleton) outlives any single UploadService instance
    // and manages its own in-flight upload state.
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
