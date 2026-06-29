import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/cloud_media_api.dart';
import '../services/upload_service.dart';

final uploadProvider = Provider<UploadNotifier>((ref) {
  final notifier = UploadNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});

class UploadNotifier {
  // Use the config that was passed to CloudMedia.initialize() so imageQuality,
  // compressAutomatically, maxSelection, etc. are all respected.
  late final UploadService _service =
      UploadService(config: CloudMedia.config);

  final Map<String, StreamController<UploadProgressData>> _controllers = {};

  Stream<UploadProgressData> getProgress(String uploadId) {
    _controllers.putIfAbsent(
        uploadId, () => StreamController<UploadProgressData>.broadcast());

    _service.getUploadProgress(uploadId).listen((p) {
      _controllers[uploadId]?.add(p);
      if (p.progress >= 1.0) {
        Future.delayed(const Duration(seconds: 2), () {
          _controllers[uploadId]?.close();
          _controllers.remove(uploadId);
        });
      }
    });

    return _controllers[uploadId]!.stream;
  }

  void dispose() {
    for (final c in _controllers.values) {
      c.close();
    }
    _controllers.clear();
    _service.dispose();
  }
}
