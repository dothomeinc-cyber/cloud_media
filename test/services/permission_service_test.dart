import 'package:cloud_media/models/cloud_media_type.dart';
import 'package:cloud_media/services/permission_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler_package/permission_handler_package.dart';

void main() {
  // Regression coverage for a real bug found and fixed this pass:
  // image/video/audio picks were requesting PermissionType.storage
  // (Android's legacy READ_EXTERNAL_STORAGE), which is a no-op on
  // Android 13+ — the OS enforces READ_MEDIA_IMAGES / READ_MEDIA_VIDEO /
  // READ_MEDIA_AUDIO instead. These tests pin the mapping so a future
  // change can't silently reintroduce that gap.
  group('PermissionService.readPermissionFor', () {
    test('image maps to the granular photos permission, not storage', () {
      expect(PermissionService.readPermissionFor(CloudMediaType.image),
          PermissionType.photos);
    });

    test('video maps to the granular videos permission, not storage', () {
      expect(PermissionService.readPermissionFor(CloudMediaType.video),
          PermissionType.videos);
    });

    test('audio maps to the granular audio permission, not microphone', () {
      // Distinguishing this from microphone matters: picking an existing
      // audio file needs library read access, not recording access.
      expect(PermissionService.readPermissionFor(CloudMediaType.audio),
          PermissionType.audio);
      expect(PermissionService.readPermissionFor(CloudMediaType.audio),
          isNot(PermissionType.microphone));
    });

    test('file (PDFs/documents) is the one case that uses storage', () {
      expect(PermissionService.readPermissionFor(CloudMediaType.file),
          PermissionType.storage);
    });

    test('every CloudMediaType maps to exactly one PermissionType', () {
      for (final type in CloudMediaType.values) {
        expect(() => PermissionService.readPermissionFor(type),
            returnsNormally);
      }
    });
  });
}
