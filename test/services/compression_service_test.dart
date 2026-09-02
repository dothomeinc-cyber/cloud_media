import 'dart:io';
import 'package:cloud_media/models/cloud_media_config.dart';
import 'package:cloud_media/services/compression_service.dart';
import 'package:cloud_media/utils/error_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CompressionService service;

  setUp(() {
    service = CompressionService(config: const CloudMediaConfig());
  });

  group('CompressionService.compressImage', () {
    // Regression coverage: compressImage used to silently return the
    // original (nonexistent) filePath unchanged when the file didn't
    // exist, indistinguishable from "compression failed, original is
    // fine to use" — which it wasn't, since there was no original to
    // fall back to. Now throws clearly instead.
    test('throws CloudMediaCompressionException for a nonexistent file',
        () async {
      final missingPath =
          '${Directory.systemTemp.path}/cloud_media_test_missing_${DateTime.now().microsecondsSinceEpoch}.jpg';

      expect(
        () => service.compressImage(missingPath),
        throwsA(isA<CloudMediaCompressionException>()),
      );
    });

    // The actual compression call (FlutterImageCompress.compressAndGetFile)
    // needs a real platform channel to exercise meaningfully — not
    // something to fake convincingly at the unit level here. What's
    // covered above is the existence-check that runs before it.
  });

  group('CompressionService.compressVideo', () {
    test('is a pass-through — returns the same path unchanged', () async {
      const path = '/some/video.mp4';
      expect(await service.compressVideo(path), path);
    });

    test('pass-through does not require the file to actually exist', () async {
      // compressVideo never touches the filesystem — it's a documented
      // v1 no-op — so this should return cleanly even for a bogus path.
      const path = '/definitely/does/not/exist.mp4';
      expect(await service.compressVideo(path), path);
    });
  });

  group('CompressionService.compress', () {
    test('routes image/* mime types to compressImage', () async {
      // Route via a nonexistent path so this stays a pure unit test
      // (compressImage throws before reaching the platform channel) —
      // the point here is just confirming the mime-type dispatch, not
      // exercising real compression.
      final missingPath =
          '${Directory.systemTemp.path}/cloud_media_test_missing2_${DateTime.now().microsecondsSinceEpoch}.jpg';

      expect(
        () => service.compress(missingPath, 'image/jpeg'),
        throwsA(isA<CloudMediaCompressionException>()),
      );
    });

    test('passes through unchanged for non-image mime types', () async {
      const path = '/some/file.mp4';
      expect(await service.compress(path, 'video/mp4'), path);

      const audioPath = '/some/file.mp3';
      expect(await service.compress(audioPath, 'audio/mpeg'), audioPath);

      const pdfPath = '/some/file.pdf';
      expect(await service.compress(pdfPath, 'application/pdf'), pdfPath);
    });
  });
}
