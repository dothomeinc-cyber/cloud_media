import 'package:cloud_media/models/cloud_media_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CloudMediaType.string', () {
    test('matches the Firestore string for every value', () {
      expect(CloudMediaType.image.string, 'image');
      expect(CloudMediaType.video.string, 'video');
      expect(CloudMediaType.audio.string, 'audio');
      expect(CloudMediaType.file.string, 'file');
    });

    test('every value has a unique string (no accidental collisions)', () {
      final strings = CloudMediaType.values.map((t) => t.string).toSet();
      expect(strings.length, CloudMediaType.values.length);
    });
  });

  group('CloudMediaType.displayName', () {
    test('is non-empty for every value', () {
      for (final type in CloudMediaType.values) {
        expect(type.displayName, isNotEmpty);
      }
    });
  });

  group('CloudMediaType.acceptedExtensions', () {
    test('image accepts jpg/jpeg/png/webp', () {
      expect(
        CloudMediaType.image.acceptedExtensions,
        containsAll(['jpg', 'jpeg', 'png', 'webp']),
      );
    });

    test('video accepts mp4/mov', () {
      expect(
        CloudMediaType.video.acceptedExtensions,
        containsAll(['mp4', 'mov']),
      );
    });

    test('audio accepts mp3/aac/m4a', () {
      expect(
        CloudMediaType.audio.acceptedExtensions,
        containsAll(['mp3', 'aac', 'm4a']),
      );
    });

    test('file accepts pdf', () {
      expect(CloudMediaType.file.acceptedExtensions, contains('pdf'));
    });

    test('no extension is claimed by two different types', () {
      final seen = <String, CloudMediaType>{};
      for (final type in CloudMediaType.values) {
        for (final ext in type.acceptedExtensions) {
          final existing = seen[ext];
          expect(
            existing,
            isNull,
            reason:
                'Extension "$ext" is claimed by both $existing and $type',
          );
          seen[ext] = type;
        }
      }
    });
  });

  group('CloudMediaType.mimeTypePrefix', () {
    test('matches the expected prefix for every value', () {
      expect(CloudMediaType.image.mimeTypePrefix, 'image/');
      expect(CloudMediaType.video.mimeTypePrefix, 'video/');
      expect(CloudMediaType.audio.mimeTypePrefix, 'audio/');
      expect(CloudMediaType.file.mimeTypePrefix, 'application/');
    });
  });
}
