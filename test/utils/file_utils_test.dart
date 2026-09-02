import 'package:cloud_media/constants/file_constants.dart';
import 'package:cloud_media/utils/file_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FileUtils.getFileExtension', () {
    test('extracts and lowercases the extension', () {
      expect(FileUtils.getFileExtension('Photo.JPG'), 'jpg');
      expect(FileUtils.getFileExtension('video.mp4'), 'mp4');
    });

    test('handles a path with multiple dots', () {
      expect(FileUtils.getFileExtension('archive.tar.gz'), 'gz');
    });

    test('returns empty string for a file with no extension', () {
      expect(FileUtils.getFileExtension('README'), '');
    });
  });

  group('FileUtils.getFileNameWithoutExtension', () {
    test('strips the extension', () {
      expect(FileUtils.getFileNameWithoutExtension('photo.jpg'), 'photo');
    });
  });

  // Regression coverage: isImage/isVideo/isAudio previously hardcoded
  // their own copies of the accepted-extension lists, separate from
  // FileConstants (and CloudMediaType.acceptedExtensions). These tests
  // check FileUtils against FileConstants directly so the two can never
  // silently drift apart again without a test failing.
  group('FileUtils.isImage / isVideo / isAudio track FileConstants', () {
    test('isImage matches every extension in FileConstants.imageExtensions',
        () {
      for (final ext in FileConstants.imageExtensions) {
        expect(FileUtils.isImage('file.$ext'), isTrue, reason: ext);
      }
    });

    test('isVideo matches every extension in FileConstants.videoExtensions',
        () {
      for (final ext in FileConstants.videoExtensions) {
        expect(FileUtils.isVideo('file.$ext'), isTrue, reason: ext);
      }
    });

    test('isAudio matches every extension in FileConstants.audioExtensions',
        () {
      for (final ext in FileConstants.audioExtensions) {
        expect(FileUtils.isAudio('file.$ext'), isTrue, reason: ext);
      }
    });

    test('isImage is false for a non-image extension', () {
      expect(FileUtils.isImage('file.mp4'), isFalse);
    });

    test('isVideo is false for a non-video extension', () {
      expect(FileUtils.isVideo('file.jpg'), isFalse);
    });

    test('isAudio is false for a non-audio extension', () {
      expect(FileUtils.isAudio('file.pdf'), isFalse);
    });
  });

  group('FileUtils.isPdf', () {
    test('true only for .pdf', () {
      expect(FileUtils.isPdf('doc.pdf'), isTrue);
      expect(FileUtils.isPdf('doc.PDF'), isTrue);
      expect(FileUtils.isPdf('doc.docx'), isFalse);
    });
  });

  group('FileUtils.formatFileSize', () {
    test('bytes under 1 KB', () {
      expect(FileUtils.formatFileSize(500), '500 B');
    });

    test('kilobytes', () {
      expect(FileUtils.formatFileSize(2048), '2.0 KB');
    });

    test('megabytes', () {
      expect(FileUtils.formatFileSize(5 * 1024 * 1024), '5.0 MB');
    });

    test('gigabytes', () {
      expect(FileUtils.formatFileSize(2 * 1024 * 1024 * 1024), '2.0 GB');
    });

    test('zero bytes', () {
      expect(FileUtils.formatFileSize(0), '0 B');
    });
  });
}
