import 'package:cloud_media/constants/file_constants.dart';
import 'package:cloud_media/models/cloud_media_type.dart';
import 'package:cloud_media/utils/error_handler.dart';
import 'package:cloud_media/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.validateFileType', () {
    test('accepts every extension in FileConstants', () {
      final all = [
        ...FileConstants.imageExtensions,
        ...FileConstants.videoExtensions,
        ...FileConstants.audioExtensions,
        ...FileConstants.documentExtensions,
      ];
      for (final ext in all) {
        expect(() => Validators.validateFileType('file.$ext'),
            returnsNormally,
            reason: ext);
      }
    });

    test('throws CloudMediaUnsupportedFileTypeException for an unknown type',
        () {
      expect(
        () => Validators.validateFileType('file.exe'),
        throwsA(isA<CloudMediaUnsupportedFileTypeException>()),
      );
    });

    test('is case-insensitive', () {
      expect(() => Validators.validateFileType('PHOTO.JPG'), returnsNormally);
    });
  });

  group('Validators.validateFileSize', () {
    test('accepts a file within the type\'s limit', () {
      expect(
        () => Validators.validateFileSize(1024, CloudMediaType.image),
        returnsNormally,
      );
    });

    test('accepts a file exactly at the type\'s limit', () {
      expect(
        () => Validators.validateFileSize(
            FileConstants.maxImageSizeBytes, CloudMediaType.image),
        returnsNormally,
      );
    });

    test('throws CloudMediaFileTooLargeException over the image limit', () {
      expect(
        () => Validators.validateFileSize(
            FileConstants.maxImageSizeBytes + 1, CloudMediaType.image),
        throwsA(isA<CloudMediaFileTooLargeException>()),
      );
    });

    test('throws over the video limit', () {
      expect(
        () => Validators.validateFileSize(
            FileConstants.maxVideoSizeBytes + 1, CloudMediaType.video),
        throwsA(isA<CloudMediaFileTooLargeException>()),
      );
    });

    test('throws over the audio limit', () {
      expect(
        () => Validators.validateFileSize(
            FileConstants.maxAudioSizeBytes + 1, CloudMediaType.audio),
        throwsA(isA<CloudMediaFileTooLargeException>()),
      );
    });

    test('throws over the document limit', () {
      expect(
        () => Validators.validateFileSize(
            FileConstants.maxDocumentSizeBytes + 1, CloudMediaType.file),
        throwsA(isA<CloudMediaFileTooLargeException>()),
      );
    });
  });

  group('Validators.validateSelectionCount', () {
    test('accepts a count within the default limit', () {
      expect(() => Validators.validateSelectionCount(5), returnsNormally);
    });

    test('throws over the default limit', () {
      expect(
        () => Validators.validateSelectionCount(
            FileConstants.defaultMaxSelection + 1),
        throwsA(isA<CloudMediaSelectionLimitExceededException>()),
      );
    });

    test('respects a custom maxAllowed', () {
      expect(
        () => Validators.validateSelectionCount(10, maxAllowed: 5),
        throwsA(isA<CloudMediaSelectionLimitExceededException>()),
      );
      expect(
        () => Validators.validateSelectionCount(5, maxAllowed: 5),
        returnsNormally,
      );
    });

    test('throws regardless of maxAllowed once past the hard limit', () {
      expect(
        () => Validators.validateSelectionCount(
          FileConstants.hardMaxSelection + 1,
          maxAllowed: FileConstants.hardMaxSelection + 50,
        ),
        throwsA(isA<CloudMediaSelectionLimitExceededException>()),
      );
    });
  });

  group('Validators.isValidUrl', () {
    test('accepts http and https URLs', () {
      expect(Validators.isValidUrl('https://example.com/file.jpg'), isTrue);
      expect(Validators.isValidUrl('http://example.com'), isTrue);
    });

    test('rejects a bare filesystem path', () {
      expect(Validators.isValidUrl('/tmp/file.jpg'), isFalse);
    });

    test('rejects a non-http scheme', () {
      expect(Validators.isValidUrl('ftp://example.com/file'), isFalse);
    });
  });

  group('Validators.isValidFileName', () {
    test('accepts a normal file name', () {
      expect(Validators.isValidFileName('my-photo_01.jpg'), isTrue);
    });

    test('rejects names containing reserved characters', () {
      for (final bad in ['a/b.jpg', 'a\\b.jpg', 'a:b.jpg', 'a*b.jpg',
          'a?b.jpg', 'a"b.jpg', 'a<b.jpg', 'a>b.jpg', 'a|b.jpg']) {
        expect(Validators.isValidFileName(bad), isFalse, reason: bad);
      }
    });
  });
}
