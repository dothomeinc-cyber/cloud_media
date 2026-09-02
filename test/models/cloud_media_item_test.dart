import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_media/models/cloud_media_item.dart';
import 'package:cloud_media/models/cloud_media_status.dart';
import 'package:cloud_media/models/cloud_media_type.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

CloudMediaItem _buildItem({
  CloudMediaStatus status = CloudMediaStatus.pending,
  DateTime? syncedAt,
  DateTime? deletedAt,
  Map<String, dynamic> metadata = const {},
}) {
  return CloudMediaItem(
    id: 'media_1',
    userId: 'user_1',
    type: CloudMediaType.image,
    fileName: 'photo.webp',
    mimeType: 'image/webp',
    size: 12345,
    width: 800,
    height: 600,
    storagePath: 'users/user_1/media/photo.webp',
    downloadUrl: 'https://example.com/photo.webp',
    thumbnailUrl: 'https://example.com/photo_thumb.webp',
    status: status,
    metadata: metadata,
    createdAt: DateTime.utc(2026, 1, 15, 10, 30),
    syncedAt: syncedAt,
    deletedAt: deletedAt,
  );
}

void main() {
  group('CloudMediaItem.toFirestore', () {
    test('serializes required fields', () {
      final item = _buildItem();
      final map = item.toFirestore();

      expect(map['userId'], 'user_1');
      expect(map['type'], 'image');
      expect(map['fileName'], 'photo.webp');
      expect(map['mimeType'], 'image/webp');
      expect(map['size'], 12345);
      expect(map['storagePath'], 'users/user_1/media/photo.webp');
      expect(map['downloadUrl'], 'https://example.com/photo.webp');
      expect(map['thumbnailUrl'], 'https://example.com/photo_thumb.webp');
      expect(map['status'], 'pending');
      expect(map['createdAt'], isA<Timestamp>());
    });

    test('omits width/height/duration when null', () {
      final item = CloudMediaItem(
        id: 'a',
        userId: 'u',
        type: CloudMediaType.audio,
        fileName: 'clip.mp3',
        mimeType: 'audio/mpeg',
        size: 100,
        storagePath: 'p',
        downloadUrl: '',
        thumbnailUrl: '',
        status: CloudMediaStatus.pending,
        createdAt: DateTime.now(),
      );
      final map = item.toFirestore();

      expect(map.containsKey('width'), isFalse);
      expect(map.containsKey('height'), isFalse);
      expect(map.containsKey('duration'), isFalse);
    });

    test('includes width/height/duration when set', () {
      final item = _buildItem();
      final map = item.toFirestore();

      expect(map['width'], 800);
      expect(map['height'], 600);
    });

    test('syncedAt and deletedAt are null when unset', () {
      final item = _buildItem();
      final map = item.toFirestore();

      expect(map['syncedAt'], isNull);
      expect(map['deletedAt'], isNull);
    });

    test('syncedAt and deletedAt serialize as Timestamp when set', () {
      final item = _buildItem(
        syncedAt: DateTime.utc(2026, 1, 16),
        deletedAt: DateTime.utc(2026, 1, 17),
      );
      final map = item.toFirestore();

      expect(map['syncedAt'], isA<Timestamp>());
      expect(map['deletedAt'], isA<Timestamp>());
    });
  });

  group('CloudMediaItem.fromFirestore', () {
    late FakeFirebaseFirestore firestore;

    setUp(() {
      firestore = FakeFirebaseFirestore();
    });

    test('round-trips a full item through real Firestore mapping', () async {
      final original = _buildItem(
        status: CloudMediaStatus.synced,
        syncedAt: DateTime.utc(2026, 1, 16, 9),
        metadata: {'source': 'gallery'},
      );

      final docRef =
          firestore.collection('media').doc(original.id);
      await docRef.set(original.toFirestore());
      final snapshot = await docRef.get();

      final restored = CloudMediaItem.fromFirestore(snapshot);

      expect(restored.id, original.id);
      expect(restored.userId, original.userId);
      expect(restored.type, CloudMediaType.image);
      expect(restored.fileName, original.fileName);
      expect(restored.mimeType, original.mimeType);
      expect(restored.size, original.size);
      expect(restored.width, original.width);
      expect(restored.height, original.height);
      expect(restored.storagePath, original.storagePath);
      expect(restored.downloadUrl, original.downloadUrl);
      expect(restored.thumbnailUrl, original.thumbnailUrl);
      expect(restored.status, CloudMediaStatus.synced);
      expect(restored.metadata, {'source': 'gallery'});
      expect(restored.syncedAt, isNotNull);
      expect(restored.deletedAt, isNull);
    });

    test('falls back to CloudMediaType.file for an unrecognized type string',
        () async {
      final docRef = firestore.collection('media').doc('bad_type');
      await docRef.set({'type': 'not_a_real_type'});
      final snapshot = await docRef.get();

      final restored = CloudMediaItem.fromFirestore(snapshot);

      expect(restored.type, CloudMediaType.file);
    });

    test(
        'falls back to CloudMediaStatus.pending for an unrecognized status string',
        () async {
      final docRef = firestore.collection('media').doc('bad_status');
      await docRef.set({'status': 'not_a_real_status'});
      final snapshot = await docRef.get();

      final restored = CloudMediaItem.fromFirestore(snapshot);

      expect(restored.status, CloudMediaStatus.pending);
    });

    test('defaults missing string fields to empty string, not null',
        () async {
      final docRef = firestore.collection('media').doc('sparse');
      await docRef.set(<String, dynamic>{});
      final snapshot = await docRef.get();

      final restored = CloudMediaItem.fromFirestore(snapshot);

      expect(restored.userId, '');
      expect(restored.fileName, '');
      expect(restored.mimeType, '');
      expect(restored.storagePath, '');
      expect(restored.downloadUrl, '');
      expect(restored.thumbnailUrl, '');
      expect(restored.size, 0);
      expect(restored.metadata, isEmpty);
    });

    test('id comes from the document id, not the stored data', () async {
      final docRef = firestore.collection('media').doc('doc_id_123');
      await docRef.set({'userId': 'u'});
      final snapshot = await docRef.get();

      final restored = CloudMediaItem.fromFirestore(snapshot);

      expect(restored.id, 'doc_id_123');
    });
  });

  group('CloudMediaItem.copyWith', () {
    test('replaces only the given fields', () {
      final original = _buildItem();
      final updated = original.copyWith(
        status: CloudMediaStatus.synced,
        downloadUrl: 'https://example.com/new.webp',
      );

      expect(updated.status, CloudMediaStatus.synced);
      expect(updated.downloadUrl, 'https://example.com/new.webp');
      // Everything else carried over unchanged.
      expect(updated.id, original.id);
      expect(updated.userId, original.userId);
      expect(updated.fileName, original.fileName);
      expect(updated.storagePath, original.storagePath);
    });

    test('with no arguments returns an equivalent copy', () {
      final original = _buildItem();
      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.status, original.status);
      expect(copy.toFirestore(), original.toFirestore());
    });
  });
}
