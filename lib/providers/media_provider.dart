import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/cloud_media_api.dart';
import '../models/cloud_media_item.dart';
import '../models/cloud_media_type.dart';

/// Lists all media for the current user.
///
/// Uses the already-initialized [CloudMediaProvider] from [CloudMedia],
/// so the user's config (imageQuality, maxSelection, etc.) is honoured.
/// Throws [StateError] if [CloudMedia.initialize] has not been called yet.
final mediaListProvider =
    FutureProvider.family<List<CloudMediaItem>, String>((ref, userId) async {
  return CloudMedia.provider.listMedia();
});

/// Fetches a single media item by its ID.
///
/// Returns null if the item does not exist or an error occurs.
final mediaItemProvider =
    FutureProvider.family<CloudMediaItem?, String>((ref, mediaId) async {
  try {
    return await CloudMedia.provider.getMedia(mediaId);
  } catch (_) {
    return null;
  }
});

/// Streams real-time updates for a single media item.
///
/// Emits a nullable item type while preserving Riverpod's AsyncError state.
final mediaStreamProvider =
    StreamProvider.family<CloudMediaItem?, String>((ref, mediaId) {
  return CloudMedia.provider
      .watchMedia(mediaId)
      .map<CloudMediaItem?>((item) => item);
});

/// Lists media filtered by [CloudMediaType].
final mediaByTypeProvider =
    FutureProvider.family<List<CloudMediaItem>, CloudMediaType>((ref, type) async {
  return CloudMedia.provider.listMedia(type: type);
});
