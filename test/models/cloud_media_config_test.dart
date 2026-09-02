import 'package:cloud_media/models/cloud_media_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CloudMediaConfig defaults', () {
    test('match the documented defaults', () {
      const config = CloudMediaConfig();

      expect(config.maxCacheSizeMb, 500);
      expect(config.imageQuality, 85);
      expect(config.thumbnailSize, 200);
      expect(config.maxSelection, 20);
      expect(config.enableOfflineSync, isTrue);
      expect(config.enableReviewScreen, isTrue);
      expect(config.enableBackgroundRemoval, isTrue);
      expect(config.uploadTimeout, const Duration(minutes: 5));
      expect(config.maxRetries, 3);
      expect(config.autoGenerateThumbnails, isTrue);
      expect(config.compressAutomatically, isTrue);
      expect(config.enableVideoCompression, isFalse);
      // enableLogging defaults to false — CloudMediaProvider.initialize()
      // wires this straight to CloudLogger.isEnabled, so a wrong default
      // here would mean every consuming app gets verbose logs whether
      // they asked for them or not.
      expect(config.enableLogging, isFalse);
      expect(config.customStorageBucket, isNull);
    });
  });

  group('CloudMediaConfig.copyWith', () {
    test('replaces only the given fields', () {
      const original = CloudMediaConfig();
      final updated = original.copyWith(
        imageQuality: 95,
        enableLogging: true,
      );

      expect(updated.imageQuality, 95);
      expect(updated.enableLogging, isTrue);
      // Untouched fields carry over.
      expect(updated.maxCacheSizeMb, original.maxCacheSizeMb);
      expect(updated.thumbnailSize, original.thumbnailSize);
      expect(updated.maxSelection, original.maxSelection);
    });

    test('with no arguments returns an equivalent config', () {
      const original = CloudMediaConfig(imageQuality: 77);
      final copy = original.copyWith();

      expect(copy.imageQuality, 77);
      expect(copy.toJson(), original.toJson());
    });

    test('can explicitly set a bool field back to its default', () {
      const original = CloudMediaConfig(enableLogging: true);
      final updated = original.copyWith(enableLogging: false);

      expect(updated.enableLogging, isFalse);
    });
  });

  group('CloudMediaConfig.toJson', () {
    test('serializes uploadTimeout as milliseconds, not a Duration object',
        () {
      const config = CloudMediaConfig(uploadTimeout: Duration(minutes: 2));
      final json = config.toJson();

      expect(json['uploadTimeoutMs'], const Duration(minutes: 2).inMilliseconds);
    });

    test('includes every configurable field', () {
      const config = CloudMediaConfig();
      final json = config.toJson();

      expect(json.keys, containsAll([
        'maxCacheSizeMb',
        'imageQuality',
        'thumbnailSize',
        'maxSelection',
        'enableOfflineSync',
        'enableReviewScreen',
        'enableBackgroundRemoval',
        'uploadTimeoutMs',
        'maxRetries',
        'autoGenerateThumbnails',
        'compressAutomatically',
        'enableVideoCompression',
        'videoCompressionBitrate',
        'enableLogging',
      ]));
    });
  });
}
