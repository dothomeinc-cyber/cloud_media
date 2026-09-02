import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_media/constants/firestore_paths.dart';
import 'package:cloud_media/models/cloud_media_config.dart';
import 'package:cloud_media/models/cloud_media_item.dart';
import 'package:cloud_media/models/cloud_media_status.dart';
import 'package:cloud_media/models/cloud_media_type.dart';
import 'package:cloud_media/services/firebase_service.dart';
import 'package:cloud_media/utils/error_handler.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late FirebaseService service;
  const uid = 'user_1';

  CloudMediaItem buildItem(String id, {bool deleted = false, CloudMediaType type = CloudMediaType.image}) {
    return CloudMediaItem(
      id: id,
      userId: uid,
      type: type,
      fileName: '$id.jpg',
      mimeType: 'image/jpeg',
      size: 1000,
      storagePath: 'users/$uid/media/$id.jpg',
      downloadUrl: 'https://example.com/$id.jpg',
      thumbnailUrl: '',
      status: CloudMediaStatus.synced,
      createdAt: DateTime.now(),
      deletedAt: deleted ? DateTime.now() : null,
    );
  }

  Future<void> seed(CloudMediaItem item) => firestore
      .doc(FirestorePaths.mediaDoc(item.userId, item.id))
      .set(item.toFirestore());

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    // MockFirebaseAuth's `mockUser` param only says WHICH user to sign
    // in as — it does NOT sign anyone in by itself. `signedIn: true` is
    // required too, confirmed against the real MockFirebaseAuth
    // constructor (signedIn defaults to false) after a real test run
    // showed currentUser was null despite mockUser being passed.
    auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: uid));
    service = FirebaseService(
      config: const CloudMediaConfig(),
      firestore: firestore,
      auth: auth,
    );
    await service.initialize();
  });

  group('FirebaseService.currentUser', () {
    test('reflects the injected auth instance', () {
      expect(service.currentUser?.uid, uid);
    });
  });

  group('FirebaseService.getMedia', () {
    test('returns the item when it exists', () async {
      await seed(buildItem('m1'));

      final media = await service.getMedia('m1');

      expect(media.id, 'm1');
      expect(media.userId, uid);
    });

    test('throws CloudMediaNotFoundException when the doc does not exist',
        () async {
      expect(
        () => service.getMedia('does_not_exist'),
        throwsA(isA<CloudMediaNotFoundException>()),
      );
    });
  });

  group('FirebaseService.listMedia', () {
    test('returns only non-deleted items, newest first', () async {
      final older = buildItem('old')
          .copyWith(createdAt: DateTime.now().subtract(const Duration(days: 1)));
      final newer = buildItem('new');
      final deleted = buildItem('gone', deleted: true);

      await seed(older);
      await seed(newer);
      await seed(deleted);

      final results = await service.listMedia();

      expect(results.map((m) => m.id), ['new', 'old']);
    });

    test('filters by type', () async {
      await seed(buildItem('img', type: CloudMediaType.image));
      await seed(buildItem('vid', type: CloudMediaType.video));

      final results = await service.listMedia(type: CloudMediaType.video);

      expect(results.map((m) => m.id), ['vid']);
    });

    test('respects the limit parameter', () async {
      for (var i = 0; i < 5; i++) {
        await seed(buildItem('item_$i'));
      }

      final results = await service.listMedia(limit: 2);

      expect(results.length, 2);
    });

    test('returns an empty list when the user has no media', () async {
      final results = await service.listMedia();
      expect(results, isEmpty);
    });
  });

  group('FirebaseService.watchMedia', () {
    test('emits updates as the document changes', () async {
      await seed(buildItem('watched'));

      final stream = service.watchMedia('watched');
      final statusesFuture = stream.map((item) => item.status).take(2).toList();

      // Give the initial snapshot a moment to be delivered to the
      // stream before triggering the update, so the two emissions
      // (initial + updated) are distinct rather than coalesced.
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await firestore
          .doc(FirestorePaths.mediaDoc(uid, 'watched'))
          .update({'status': CloudMediaStatus.failed.name});

      final statuses = await statusesFuture;

      expect(statuses.first, CloudMediaStatus.synced);
      expect(statuses.last, CloudMediaStatus.failed);
    });
  });

  group('FirebaseService.deleteMedia', () {
    test('soft-deletes by setting deletedAt and status', () async {
      await seed(buildItem('to_delete'));

      await service.deleteMedia('to_delete');

      final doc = await firestore
          .doc(FirestorePaths.mediaDoc(uid, 'to_delete'))
          .get();
      final data = doc.data()!;
      expect(data['deletedAt'], isA<Timestamp>());
      expect(data['status'], CloudMediaStatus.deleted.name);
    });
  });

  group('FirebaseService.restoreMedia', () {
    test('clears deletedAt and restores synced status', () async {
      await seed(buildItem('to_restore', deleted: true));

      await service.restoreMedia('to_restore');

      final doc = await firestore
          .doc(FirestorePaths.mediaDoc(uid, 'to_restore'))
          .get();
      final data = doc.data()!;
      expect(data['deletedAt'], isNull);
      expect(data['status'], CloudMediaStatus.synced.name);
    });
  });

  group('FirebaseService with no authenticated user', () {
    test('getMedia throws CloudMediaPermissionDeniedException', () async {
      final unauthedAuth = MockFirebaseAuth();
      // Sanity-check the fixture's own assumption before relying on it —
      // if firebase_auth_mocks' default ever changes to start with a
      // signed-in user, this fails with a clear message pointing at the
      // fixture itself rather than a confusing failure inside
      // FirebaseService.
      expect(unauthedAuth.currentUser, isNull,
          reason:
              'This test assumes MockFirebaseAuth() with no arguments has '
              'no signed-in user by default.');

      final unauthedService = FirebaseService(
        config: const CloudMediaConfig(),
        firestore: firestore,
        auth: unauthedAuth,
      );
      await unauthedService.initialize();

      expect(
        () => unauthedService.getMedia('anything'),
        throwsA(isA<CloudMediaPermissionDeniedException>()),
      );
    });
  });
}
