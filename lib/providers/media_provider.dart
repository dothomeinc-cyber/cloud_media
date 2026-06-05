import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cloud_media_config.dart';
import '../models/cloud_media_item.dart';
import '../services/firebase_service.dart';

final mediaListProvider =
    FutureProvider.family<List<CloudMediaItem>, String>((ref, userId) async {
  final service = FirebaseService(config: const CloudMediaConfig());
  await service.initialize();
  return service.getUserMedia();
});

final mediaItemProvider =
    FutureProvider.family<CloudMediaItem?, String>((ref, mediaId) async {
  final service = FirebaseService(config: const CloudMediaConfig());
  await service.initialize();
  try {
    return await service.getMedia(mediaId);
  } catch (_) {
    return null;
  }
});

final mediaStreamProvider =
    StreamProvider.family<CloudMediaItem?, String>((ref, mediaId) {
  final service = FirebaseService(config: const CloudMediaConfig());
  return service.watchMedia(mediaId).handleError((_) => null);
});
