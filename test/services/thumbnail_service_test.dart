import 'dart:typed_data';
import 'package:cloud_media/models/cloud_media_config.dart';
import 'package:cloud_media/services/thumbnail_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List _pngBytesOf(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(120, 180, 220));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  late ThumbnailService service;

  setUp(() {
    service = ThumbnailService(config: const CloudMediaConfig());
  });

  group('ThumbnailService.generateThumbnailBytes', () {
    test('produces valid, decodable JPEG bytes from a real PNG image',
        () async {
      final source = _pngBytesOf(400, 300);

      final thumbBytes = await service.generateThumbnailBytes(source, 100);

      expect(thumbBytes, isNotNull);
      final decoded = img.decodeImage(thumbBytes!);
      expect(decoded, isNotNull);
    });

    test('crops to a square of the requested size', () async {
      // A non-square source to confirm copyResizeCropSquare actually
      // crops rather than just resizing while preserving aspect ratio.
      final source = _pngBytesOf(400, 200);

      final thumbBytes = await service.generateThumbnailBytes(source, 64);
      final decoded = img.decodeImage(thumbBytes!)!;

      expect(decoded.width, 64);
      expect(decoded.height, 64);
    });

    test('handles a source image smaller than the requested thumbnail size',
        () async {
      final source = _pngBytesOf(20, 20);

      final thumbBytes = await service.generateThumbnailBytes(source, 100);

      expect(thumbBytes, isNotNull);
    });

    test('returns null for bytes that are not a decodable image', () async {
      final garbage = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

      final result = await service.generateThumbnailBytes(garbage, 100);

      expect(result, isNull);
    });

    test('returns null for empty bytes rather than throwing', () async {
      final result =
          await service.generateThumbnailBytes(Uint8List(0), 100);
      expect(result, isNull);
    });
  });
}
