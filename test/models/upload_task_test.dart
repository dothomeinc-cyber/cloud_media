import 'package:cloud_media/models/cloud_media_type.dart';
import 'package:cloud_media/models/upload_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  UploadTask buildTask({UploadTaskStatus status = UploadTaskStatus.pending}) {
    return UploadTask(
      id: 'task_1',
      mediaId: 'media_1',
      localPath: '/tmp/photo.webp',
      storagePath: 'users/u/media/photo.webp',
      type: CloudMediaType.image,
      createdAt: DateTime.utc(2026, 1, 15, 10),
      taskStatus: status,
    );
  }

  group('UploadTask.toJson / fromJson round-trip', () {
    test('preserves every field', () {
      final original = buildTask(status: UploadTaskStatus.uploading)
          .copyWith(retryCount: 2, lastAttemptAt: DateTime.utc(2026, 1, 15, 11));

      final restored = UploadTask.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.mediaId, original.mediaId);
      expect(restored.localPath, original.localPath);
      expect(restored.storagePath, original.storagePath);
      expect(restored.type, original.type);
      expect(restored.retryCount, original.retryCount);
      expect(restored.createdAt, original.createdAt);
      expect(restored.lastAttemptAt, original.lastAttemptAt);
      expect(restored.taskStatus, original.taskStatus);
    });

    test('lastAttemptAt round-trips as null when unset', () {
      final original = buildTask();
      final restored = UploadTask.fromJson(original.toJson());

      expect(restored.lastAttemptAt, isNull);
    });

    test('falls back to CloudMediaType.file for an unrecognized type', () {
      final json = buildTask().toJson();
      json['type'] = 'not_a_real_type';

      final restored = UploadTask.fromJson(json);

      expect(restored.type, CloudMediaType.file);
    });

    test('falls back to UploadTaskStatus.pending for an unrecognized status',
        () {
      final json = buildTask().toJson();
      json['taskStatus'] = 'not_a_real_status';

      final restored = UploadTask.fromJson(json);

      expect(restored.taskStatus, UploadTaskStatus.pending);
    });

    test('missing retryCount defaults to 0', () {
      final json = buildTask().toJson();
      json.remove('retryCount');

      final restored = UploadTask.fromJson(json);

      expect(restored.retryCount, 0);
    });
  });

  group('UploadTask.copyWith', () {
    test('replaces only the given fields', () {
      final original = buildTask();
      final updated = original.copyWith(
        taskStatus: UploadTaskStatus.completed,
        retryCount: 3,
      );

      expect(updated.taskStatus, UploadTaskStatus.completed);
      expect(updated.retryCount, 3);
      expect(updated.id, original.id);
      expect(updated.mediaId, original.mediaId);
    });
  });
}
