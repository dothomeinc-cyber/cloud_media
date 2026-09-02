import 'package:cloud_media/models/compression_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CompressionProfile.imageQuality', () {
    test('high is the highest quality', () {
      final maxOther = [
        CompressionProfile.product,
        CompressionProfile.avatar,
        CompressionProfile.thumbnail,
      ].map((p) => p.imageQuality).reduce((a, b) => a > b ? a : b);
      expect(CompressionProfile.high.imageQuality, greaterThan(maxOther));
    });

    test('thumbnail is the most aggressive (lowest quality)', () {
      final minOther = [
        CompressionProfile.high,
        CompressionProfile.product,
        CompressionProfile.avatar,
      ].map((p) => p.imageQuality).reduce((a, b) => a < b ? a : b);
      expect(
          CompressionProfile.thumbnail.imageQuality, lessThan(minOther));
    });

    test('none is full quality (100)', () {
      expect(CompressionProfile.none.imageQuality, 100);
    });

    test('every quality is within the valid 1-100 range', () {
      for (final profile in CompressionProfile.values) {
        expect(profile.imageQuality, inInclusiveRange(1, 100));
      }
    });
  });

  group('CompressionProfile.thumbnailSize', () {
    test('every size is positive', () {
      for (final profile in CompressionProfile.values) {
        expect(profile.thumbnailSize, greaterThan(0));
      }
    });

    test('avatar and thumbnail are smaller than product and high', () {
      expect(CompressionProfile.avatar.thumbnailSize,
          lessThan(CompressionProfile.product.thumbnailSize));
      expect(CompressionProfile.thumbnail.thumbnailSize,
          lessThan(CompressionProfile.high.thumbnailSize));
    });
  });

  group('CompressionProfile.compress', () {
    test('none disables compression', () {
      expect(CompressionProfile.none.compress, isFalse);
    });

    test('every other profile enables compression', () {
      for (final profile in CompressionProfile.values) {
        if (profile == CompressionProfile.none) continue;
        expect(profile.compress, isTrue, reason: '$profile should compress');
      }
    });
  });
}
