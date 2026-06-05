import 'package:cloud_firestore/cloud_firestore.dart';
import 'cloud_media_type.dart';
import 'cloud_media_status.dart';

class CloudMediaItem {
  final String id;
  final String userId;
  final CloudMediaType type;
  final String fileName;
  final String mimeType;
  final int size;
  final int? width;
  final int? height;
  final double? duration;
  final String storagePath;
  final String downloadUrl;
  final String thumbnailUrl;
  final CloudMediaStatus status;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime? syncedAt;
  final DateTime? deletedAt;
  final String? localPath;

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
