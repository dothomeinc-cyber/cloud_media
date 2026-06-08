import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/firestore_paths.dart';
import '../models/cloud_media_config.dart';
import '../models/cloud_media_item.dart';
import '../models/cloud_media_status.dart';
import '../models/cloud_media_type.dart';
import '../utils/error_handler.dart';
import '../utils/logger.dart';

/// Service that handles all Firebase Firestore and Storage operations.
///
/// Requires Firebase to be initialized by the host app before use.
/// Uses [FirebaseAuth] to identify the current user.
class FirebaseService {
  /// Creates a [FirebaseService] with the given [config].
  FirebaseService({required this.config});

  /// The configuration for this service.
  final CloudMediaConfig config;

  late FirebaseFirestore _firestore;
  late FirebaseStorage _storage;

  /// Initialize Firebase instances. Must be called before any other method.
  Future<void> initialize() async {
    _firestore = FirebaseFirestore.instance;
    _storage = config.customStorageBucket != null
        ? FirebaseStorage.instanceFor(bucket: config.customStorageBucket)
        : FirebaseStorage.instance;
    CloudLogger.info('FirebaseService ready. User: ${currentUser?.uid}');
  }

  /// The currently authenticated Firebase user, or null if not signed in.
  User? get currentUser => FirebaseAuth.instance.currentUser;

  String get _uid {
    final uid = currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw const CloudMediaPermissionDeniedException(
          'No authenticated user.');
    }
    return uid;
  }

  /// Fetch a single media item by [mediaId].
  ///
  /// Throws [CloudMediaNotFoundException] if the item does not exist.
  Future<CloudMediaItem> getMedia(String mediaId) async {
    final doc =
        await _firestore.doc(FirestorePaths.mediaDoc(_uid, mediaId)).get();
    if (!doc.exists) throw CloudMediaNotFoundException('Not found: $mediaId');
    return CloudMediaItem.fromFirestore(doc);
  }

  /// Alias for [listMedia] with no filters.
  Future<List<CloudMediaItem>> getUserMedia() => listMedia();

  /// List media for the current user with optional filters.
  ///
  /// Supports filtering by [type], [startDate], [endDate], and pagination
  /// via [limit] and [offset].
  Future<List<CloudMediaItem>> listMedia({
    CloudMediaType? type,
    int limit = 50,
    int offset = 0,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    Query query = _firestore
        .collection(FirestorePaths.userMedia(_uid))
        .where('deletedAt', isNull: true)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (type != null) {
      query = query.where('type', isEqualTo: type.string);
    }
    if (startDate != null) {
      query = query.where('createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }
    if (endDate != null) {
      query = query.where('createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    final snap = await query.get();
    return snap.docs.map(CloudMediaItem.fromFirestore).toList();
  }

  /// Watch real-time updates for a media item.
  Stream<CloudMediaItem> watchMedia(String mediaId) => _firestore
      .doc(FirestorePaths.mediaDoc(_uid, mediaId))
      .snapshots()
      .map(CloudMediaItem.fromFirestore);

  /// Soft-delete a media item by setting [deletedAt] timestamp.
  Future<void> deleteMedia(String mediaId) async {
    await _firestore.doc(FirestorePaths.mediaDoc(_uid, mediaId)).update({
      'deletedAt': Timestamp.now(),
      'status': CloudMediaStatus.deleted.name,
    });
  }

  /// Restore a soft-deleted media item.
  Future<void> restoreMedia(String mediaId) async {
    await _firestore.doc(FirestorePaths.mediaDoc(_uid, mediaId)).update({
      'deletedAt': null,
      'status': CloudMediaStatus.synced.name,
    });
  }

  /// Download a media item to the device's temp directory.
  ///
  /// Returns the local file path.
  Future<String> downloadMedia(String mediaId) async {
    final media = await getMedia(mediaId);
    if (media.downloadUrl.isEmpty) {
      throw CloudMediaUploadFailedException('No URL for: $mediaId');
    }
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/${mediaId}_${media.fileName}';
    await _storage.ref(media.storagePath).writeToFile(File(filePath));
    return filePath;
  }

  /// Share a media item using the platform share sheet.
  Future<void> shareMedia(CloudMediaItem media) async {
    if (media.downloadUrl.isNotEmpty) {
      await SharePlus.instance.share(
        ShareParams(uri: Uri.parse(media.downloadUrl)),
      );
    } else {
      final path = await downloadMedia(media.id);
      await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
    }
  }
}
