import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/cloud_media_api.dart';
import '../services/upload_service.dart';

final uploadProvider = Provider<UploadNotifier>((ref) {
  final notifier = UploadNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});

/// Riverpod-facing wrapper around [UploadService]'s upload lifecycle.
///
/// [getProgress] passes through directly to
/// [UploadService.getUploadProgress]'s broadcast stream (itself backed by
/// [OfflineSyncService]) rather than re-wrapping it in a second
/// StreamController — that stream already multiplexes to any number of
/// listeners and closes itself when the upload finishes, so there is
/// nothing extra to manage here.
class UploadNotifier {
  // Use the config that was passed to CloudMedia.initialize() so imageQuality,
  // compressAutomatically, maxSelection, etc. are all respected.
  final UploadService _service = UploadService(config: CloudMedia.config);

  /// Live progress for [mediaId]'s upload.
  Stream<UploadProgressData> getProgress(String mediaId) =>
      _service.getUploadProgress(mediaId);

  /// Pause an in-flight upload. No-op if it isn't currently uploading.
  void pause(String mediaId) => _service.pauseUpload(mediaId);

  /// Resume a paused upload. No-op if it isn't currently uploading.
  void resume(String mediaId) => _service.resumeUpload(mediaId);

  /// Cancel an in-flight upload. No-op if it isn't currently uploading.
  void cancel(String mediaId) => _service.cancelUpload(mediaId);

  /// True while [mediaId]'s upload is actively talking to Firebase Storage.
  bool isUploading(String mediaId) => _service.isUploading(mediaId);

  void dispose() {
    _service.dispose();
  }
}
