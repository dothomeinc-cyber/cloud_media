import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:riverpod_offline_sync/riverpod_offline_sync.dart';

class StorageQueueService {
  StorageQueueService._();
  static final StorageQueue _queue = StorageQueue();
  static final Map<String, String> _keys = {};

  static Future<void> uploadFile({
    required File file, required String storagePath,
    required String mediaId, required String userId,
    VoidCallback? onComplete, void Function(double)? onProgress,
  }) async {
    final key = IdempotencyKey.generate();
    _keys[mediaId] = key;
    final ref = FirebaseStorage.instance.ref(storagePath);
    await ref.putFile(file, SettableMetadata(
      customMetadata: {'userId': userId, 'mediaId': mediaId,
                       'uploadedAt': DateTime.now().toIso8601String()},
    ));
    onComplete?.call();
    onProgress?.call(1.0);
    _keys.remove(mediaId);
  }

  static void pauseUpload(String mediaId) {
    final key = _keys[mediaId];
    if (key != null) _queue.pauseUpload(key);
  }

  static void resumeUpload(String mediaId) {
    final key = _keys[mediaId];
    if (key != null) _queue.resumeUpload(key);
  }

  static void cancelUpload(String mediaId) {
    final key = _keys[mediaId];
    if (key != null) { _queue.cancelUpload(key); _keys.remove(mediaId); }
  }
}
