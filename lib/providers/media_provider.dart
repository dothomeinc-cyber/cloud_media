import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/cloud_media_api.dart';
import '../models/cloud_media_item.dart';
import '../models/cloud_media_type.dart';

/// Lists all media for the current user.
///
/// Uses the already-initialized [CloudMediaProvider] from [CloudMedia],
/// so the user's config (imageQuality, maxSelection, etc.) is honoured.
/// Throws [StateError] if [CloudMedia.initialize] has not been called yet.
///
/// This is scoped to whichever user is currently signed in via
/// `FirebaseAuth.instance.currentUser` — there's no way to query another
/// user's media anywhere in this package (every Firestore path is built
/// from the current auth user's uid), so this is a plain [FutureProvider],
/// not a `.family`. It previously took an ignored `String userId` family
/// parameter that looked like it selected which user's media to list but
/// never actually did anything with it — always returning the current
/// user's media regardless of what was passed in, which is actively
/// misleading for exactly the kind of multi-user use case that parameter
/// implied was supported.
final mediaListProvider = FutureProvider<List<CloudMediaItem>>((ref) async {
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
