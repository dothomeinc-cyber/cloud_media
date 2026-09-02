import 'dart:io';
import 'package:cloud_media/services/background_removal_service.dart';
import 'package:cloud_media/utils/error_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = BackgroundRemovalService();

  group('BackgroundRemovalService.removeBackground', () {
    // Regression coverage: this used to silently return the input path
    // unchanged for an empty/nonexistent path — indistinguishable from
    // "native removal failed, the original is fine to use" — which it
    // wasn't, since there was no valid original. Same fix and same
    // reasoning as CompressionService.compressImage.
    test('throws CloudMediaInvalidInputException for an empty path',
        () async {
      expect(
        () => service.removeBackground(''),
        throwsA(isA<CloudMediaInvalidInputException>()),
      );
    });

    test('throws CloudMediaInvalidInputException for whitespace-only path',
        () async {
      expect(
        () => service.removeBackground('   '),
        throwsA(isA<CloudMediaInvalidInputException>()),
      );
    });

    test('throws CloudMediaInvalidInputException for a nonexistent file',
        () async {
      final missingPath =
          '${Directory.systemTemp.path}/cloud_media_test_missing_bg_${DateTime.now().microsecondsSinceEpoch}.jpg';

      expect(
        () => service.removeBackground(missingPath),
        throwsA(isA<CloudMediaInvalidInputException>()),
      );
    });

    // The actual NativeCutout.removeBackground call needs a real device
    // with ML Kit / Vision framework support to exercise meaningfully —
    // not something to fake at the unit level here. What's covered
    // above is the precondition check that runs before it.
  });

  group('BackgroundRemovalService — const constructor', () {
    test('can be constructed as a compile-time constant', () {
      const a = BackgroundRemovalService();
      const b = BackgroundRemovalService();
      // Both refer to the same canonicalized const instance.
      expect(identical(a, b), isTrue);
    });
  });
}
