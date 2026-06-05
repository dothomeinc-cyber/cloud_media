import 'cloud_media_type.dart';

class UploadTask {
  final String id;
  final String mediaId;
  final String localPath;
  final String storagePath;
  final CloudMediaType type;
  final int retryCount;
  final DateTime createdAt;
  final DateTime? lastAttemptAt;
  final UploadTaskStatus taskStatus;

  const UploadTask({
    required this.id,
    required this.mediaId,
    required this.localPath,
    required this.storagePath,
    required this.type,
    this.retryCount = 0,
    required this.createdAt,
    this.lastAttemptAt,
    this.taskStatus = UploadTaskStatus.pending,
  });

  UploadTask copyWith({
    String? id,
    String? mediaId,
    String? localPath,
    String? storagePath,
    CloudMediaType? type,
    int? retryCount,
    DateTime? createdAt,
    DateTime? lastAttemptAt,
    UploadTaskStatus? taskStatus,
  }) {
    return UploadTask(
      id: id ?? this.id,
      mediaId: mediaId ?? this.mediaId,
      localPath: localPath ?? this.localPath,
      storagePath: storagePath ?? this.storagePath,
      type: type ?? this.type,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      taskStatus: taskStatus ?? this.taskStatus,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'mediaId': mediaId,
        'localPath': localPath,
        'storagePath': storagePath,
        'type': type.string,
        'retryCount': retryCount,
        'createdAt': createdAt.toIso8601String(),
        'lastAttemptAt': lastAttemptAt?.toIso8601String(),
        'taskStatus': taskStatus.name,
      };

  factory UploadTask.fromJson(Map<String, dynamic> json) {
    return UploadTask(
      id: json['id'] as String,
      mediaId: json['mediaId'] as String,
      localPath: json['localPath'] as String,
      storagePath: json['storagePath'] as String,
      type: CloudMediaType.values.firstWhere(
        (e) => e.string == json['type'],
        orElse: () => CloudMediaType.file,
      ),
      retryCount: json['retryCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastAttemptAt: json['lastAttemptAt'] != null
          ? DateTime.parse(json['lastAttemptAt'] as String)
          : null,
      taskStatus: UploadTaskStatus.values.firstWhere(
        (e) => e.name == json['taskStatus'],
        orElse: () => UploadTaskStatus.pending,
      ),
    );
  }
}

enum UploadTaskStatus { pending, uploading, completed, failed, cancelled }
