import 'package:cloud_media/models/cloud_media_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CloudMediaStatus.isFinal', () {
    test('synced, failed, and deleted are final', () {
      expect(CloudMediaStatus.synced.isFinal, isTrue);
      expect(CloudMediaStatus.failed.isFinal, isTrue);
      expect(CloudMediaStatus.deleted.isFinal, isTrue);
    });

    test('pending, processing, and syncing are not final', () {
      expect(CloudMediaStatus.pending.isFinal, isFalse);
      expect(CloudMediaStatus.processing.isFinal, isFalse);
      expect(CloudMediaStatus.syncing.isFinal, isFalse);
    });
  });

  group('CloudMediaStatus.isUploading', () {
    test('processing and syncing count as uploading', () {
      expect(CloudMediaStatus.processing.isUploading, isTrue);
      expect(CloudMediaStatus.syncing.isUploading, isTrue);
    });

    test('pending, synced, failed, and deleted do not', () {
      expect(CloudMediaStatus.pending.isUploading, isFalse);
      expect(CloudMediaStatus.synced.isUploading, isFalse);
      expect(CloudMediaStatus.failed.isUploading, isFalse);
      expect(CloudMediaStatus.deleted.isUploading, isFalse);
    });
  });

  group('CloudMediaStatus.displayName', () {
    test('is non-empty and unique for every value', () {
      final names = <String>{};
      for (final status in CloudMediaStatus.values) {
        expect(status.displayName, isNotEmpty);
        names.add(status.displayName);
      }
      expect(names.length, CloudMediaStatus.values.length);
    });
  });
}
