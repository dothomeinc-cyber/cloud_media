import 'package:cloud_firestore/cloud_firestore.dart';
import 'cloud_media_type.dart';
import 'cloud_media_status.dart';

/// Represents a single media item managed by CloudMedia.
///
/// Returned by [CloudMedia.pick], [CloudMedia.list], and [CloudMedia.get].
///
/// A media item starts with [status] = [CloudMediaStatus.pending] and
/// transitions to [CloudMediaStatus.synced] once uploaded to Firebase.
/// The [localPath] is available immediately; [downloadUrl] is populated
/// after the upload completes.
class CloudMediaItem {
  /// Unique identifier for this media item (UUID).
  final String id;

  /// The Firebase Auth UID of the user who owns this item.
  final String userId;

  /// The type of media (image, video, audio, or file).
  final CloudMediaType type;

  /// The original file name including extension.
  final String fileName;

  /// The MIME type of the file (e.g. `image/webp`, `video/mp4`).
  final String mimeType;

  /// File size in bytes.
  final int size;

  /// Image or video width in pixels, if available.
  final int? width;

  /// Image or video height in pixels, if available.
  final int? height;

  /// Audio or video duration in seconds, if available.
  final double? duration;

  /// Firebase Storage path where the file is stored.
  final String storagePath;

  /// Firebase Storage download URL. Empty until [status] is [CloudMediaStatus.synced].
  final String downloadUrl;

  /// Firebase Storage URL for the generated thumbnail.
  final String thumbnailUrl;

  /// Current sync status of this media item.
  final CloudMediaStatus status;

  /// Additional metadata stored alongside this item in Firestore.
  final Map<String, dynamic> metadata;

  /// When this item was created on the device.
  final DateTime createdAt;

  /// When this item was successfully synced to Firebase. Null if not yet synced.
  final DateTime? syncedAt;

  /// When this item was soft-deleted. Null if not deleted.
  final DateTime? deletedAt;

  /// Local file path on the device. Available immediately after picking,
  /// before the upload completes.
  final String? localPath;

  /// Creates a [CloudMediaItem].
  const CloudMediaItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.fileName,
    required this.mimeType,
    required this.size,
    this.width,
    this.height,
    this.duration,
    required this.storagePath,
    required this.downloadUrl,
    required this.thumbnailUrl,
    required this.status,
    this.metadata = const {},
    required this.createdAt,
    this.syncedAt,
    this.deletedAt,
    this.localPath,
  });

  /// Creates a [CloudMediaItem] from a Firestore document snapshot.
  factory CloudMediaItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CloudMediaItem(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      type: CloudMediaType.values.firstWhere(
        (e) => e.string == data['type'],
        orElse: () => CloudMediaType.file,
      ),
      fileName: data['fileName'] as String? ?? '',
      mimeType: data['mimeType'] as String? ?? '',
      size: data['size'] as int? ?? 0,
      width: data['width'] as int?,
      height: data['height'] as int?,
      duration: (data['duration'] as num?)?.toDouble(),
      storagePath: data['storagePath'] as String? ?? '',
      downloadUrl: data['downloadUrl'] as String? ?? '',
      thumbnailUrl: data['thumbnailUrl'] as String? ?? '',
      status: CloudMediaStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => CloudMediaStatus.pending,
      ),
      metadata: (data['metadata'] as Map<String, dynamic>?) ?? {},
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      syncedAt: (data['syncedAt'] as Timestamp?)?.toDate(),
      deletedAt: (data['deletedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Serializes this item to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type.string,
      'fileName': fileName,
      'mimeType': mimeType,
      'size': size,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (duration != null) 'duration': duration,
      'storagePath': storagePath,
      'downloadUrl': downloadUrl,
      'thumbnailUrl': thumbnailUrl,
      'status': status.name,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'syncedAt': syncedAt != null ? Timestamp.fromDate(syncedAt!) : null,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    };
  }

  /// Creates a copy of this item with the given fields replaced.
  CloudMediaItem copyWith({
    String? id,
    String? userId,
    CloudMediaType? type,
    String? fileName,
    String? mimeType,
    int? size,
    int? width,
    int? height,
    double? duration,
    String? storagePath,
    String? downloadUrl,
    String? thumbnailUrl,
    CloudMediaStatus? status,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? syncedAt,
    DateTime? deletedAt,
    String? localPath,
  }) {
    return CloudMediaItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      size: size ?? this.size,
      width: width ?? this.width,
      height: height ?? this.height,
      duration: duration ?? this.duration,
      storagePath: storagePath ?? this.storagePath,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      localPath: localPath ?? this.localPath,
    );
  }
}
