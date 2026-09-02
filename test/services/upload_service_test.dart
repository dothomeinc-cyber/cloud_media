import 'dart:io';
import 'package:cloud_media/services/upload_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PickedFile.name', () {
    test('extracts the file name from a full path', () {
      expect(PickedFile('/storage/emulated/0/photo.jpg').name, 'photo.jpg');
    });

    test('handles a path with no directory component', () {
      expect(PickedFile('photo.jpg').name, 'photo.jpg');
    });
  });

  group('PickedFile.mimeType', () {
    test('maps every FileConstants-accepted extension correctly', () {
      final expected = {
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'png': 'image/png',
        'webp': 'image/webp',
        'mp4': 'video/mp4',
        'mov': 'video/quicktime',
        'mp3': 'audio/mpeg',
        'aac': 'audio/aac',
        'm4a': 'audio/m4a',
        'pdf': 'application/pdf',
      };
      expected.forEach((ext, mime) {
        expect(PickedFile('/tmp/file.$ext').mimeType, mime, reason: ext);
      });
    });

    test('is case-insensitive on the extension', () {
      expect(PickedFile('/tmp/PHOTO.JPG').mimeType, 'image/jpeg');
    });

    test('falls back to application/octet-stream for an unknown extension',
        () {
      expect(PickedFile('/tmp/file.xyz').mimeType, 'application/octet-stream');
    });

    test('handles a path with multiple dots by using the last segment', () {
      expect(PickedFile('/tmp/archive.tar.gz').mimeType,
          'application/octet-stream');
      expect(PickedFile('/tmp/my.photo.jpg').mimeType, 'image/jpeg');
    });
  });

  group('PickedFile.length', () {
    test('returns the real file size for an existing file', () async {
      final tempFile = File(
          '${Directory.systemTemp.path}/cloud_media_test_${DateTime.now().millisecondsSinceEpoch}.txt');
      await tempFile.writeAsBytes(List.filled(1234, 0));
      addTearDown(() => tempFile.delete());

      final picked = PickedFile(tempFile.path);
      expect(await picked.length(), 1234);
    });

    test('throws for a path that does not exist', () async {
      final picked = PickedFile(
          '${Directory.systemTemp.path}/cloud_media_definitely_not_a_real_file_${DateTime.now().microsecondsSinceEpoch}.jpg');
      expect(picked.length(), throwsA(isA<FileSystemException>()));
    });
  });

  group('UploadProgressData', () {
    test('carries the fields it was constructed with', () {
      const data = UploadProgressData(progress: 0.42, uploaded: 42, total: 100);
      expect(data.progress, 0.42);
      expect(data.uploaded, 42);
      expect(data.total, 100);
      expect(data.status, 'uploading');
    });

    test('status defaults to uploading but can be overridden', () {
      const data = UploadProgressData(
          progress: 1.0, uploaded: 100, total: 100, status: 'completed');
      expect(data.status, 'completed');
    });
  });
}
