import 'dart:io';
import 'package:cloud_media/constants/error_messages.dart';
import 'package:cloud_media/utils/error_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CloudMedia exception default messages', () {
    // Regression coverage: these defaults previously duplicated
    // ErrorMessages' text with independently-drifted wording. They now
    // reference ErrorMessages directly, so this just confirms the wiring
    // holds — if someone edits one without the other, this won't catch
    // wording drift (there's only one string now), but it will catch a
    // future accidental revert to a hardcoded literal.
    test('CloudMediaPermissionDeniedException uses ErrorMessages.permissionDenied',
        () {
      expect(const CloudMediaPermissionDeniedException().message,
          ErrorMessages.permissionDenied);
    });

    test(
        'CloudMediaPermissionPermanentlyDeniedException uses ErrorMessages.permissionPermanentlyDenied',
        () {
      expect(
          const CloudMediaPermissionPermanentlyDeniedException().message,
          ErrorMessages.permissionPermanentlyDenied);
    });

    test('a custom message overrides the default', () {
      const custom = CloudMediaPermissionDeniedException('custom text');
      expect(custom.message, 'custom text');
    });
  });

  group('ErrorHandler.handle with the package\'s own exceptions', () {
    // Regression coverage: handle() previously didn't recognize any of
    // these, so they fell through to the generic catch-all and produced
    // an ugly "CloudMediaXyzException: <message>" string via
    // error.toString() instead of the exception's own clean message.
    test('recognizes CloudMediaPermissionDeniedException', () {
      final result =
          ErrorHandler.handle(const CloudMediaPermissionDeniedException());
      expect(result.code, 'permission_denied');
      expect(result.message, ErrorMessages.permissionDenied);
    });

    test('recognizes CloudMediaPermissionPermanentlyDeniedException', () {
      final result = ErrorHandler.handle(
          const CloudMediaPermissionPermanentlyDeniedException());
      expect(result.code, 'permission_permanently_denied');
    });

    test('recognizes CloudMediaUnsupportedFileTypeException', () {
      final result = ErrorHandler.handle(
          const CloudMediaUnsupportedFileTypeException());
      expect(result.code, 'unsupported_file_type');
    });

    test('recognizes CloudMediaFileTooLargeException', () {
      final result =
          ErrorHandler.handle(const CloudMediaFileTooLargeException());
      expect(result.code, 'file_too_large');
    });

    test('recognizes CloudMediaUploadFailedException', () {
      final result =
          ErrorHandler.handle(const CloudMediaUploadFailedException());
      expect(result.code, 'upload_failed');
    });

    test('recognizes CloudMediaNotFoundException', () {
      final result = ErrorHandler.handle(const CloudMediaNotFoundException());
      expect(result.code, 'not_found');
    });

    test('recognizes CloudMediaInvalidInputException', () {
      final result =
          ErrorHandler.handle(const CloudMediaInvalidInputException());
      expect(result.code, 'invalid_input');
    });

    test('preserves a custom message rather than using the default', () {
      final result = ErrorHandler.handle(
          const CloudMediaPermissionDeniedException('very specific reason'));
      expect(result.message, 'very specific reason');
    });

    test('getUserFriendlyMessage returns the clean message, not toString()',
        () {
      final message = ErrorHandler.getUserFriendlyMessage(
          const CloudMediaFileTooLargeException());
      expect(message, isNot(contains('CloudMediaFileTooLargeException')));
      expect(message, ErrorMessages.fileTooLarge);
    });
  });

  group('ErrorHandler.isPermissionError', () {
    // Regression coverage: previously only matched the plain-denied
    // code, missing the permanently-denied case entirely.
    test('true for a plain denial', () {
      expect(
          ErrorHandler.isPermissionError(
              const CloudMediaPermissionDeniedException()),
          isTrue);
    });

    test('true for a permanent denial', () {
      expect(
          ErrorHandler.isPermissionError(
              const CloudMediaPermissionPermanentlyDeniedException()),
          isTrue);
    });

    test('false for an unrelated error', () {
      expect(
          ErrorHandler.isPermissionError(
              const CloudMediaFileTooLargeException()),
          isFalse);
    });
  });

  group('ErrorHandler.isNetworkError', () {
    test('true for a SocketException', () {
      expect(
          ErrorHandler.isNetworkError(
              const SocketException('no route to host')),
          isTrue);
    });

    test('false for an unrelated error', () {
      expect(
          ErrorHandler.isNetworkError(
              const CloudMediaFileTooLargeException()),
          isFalse);
    });
  });

  group('ErrorHandler.handle with an arbitrary error', () {
    test('falls back to unknown_error with error.toString() as the message',
        () {
      final result = ErrorHandler.handle(StateError('something broke'));
      expect(result.code, 'unknown_error');
      expect(result.message, contains('something broke'));
    });

    test('handle is idempotent for an already-handled CloudMediaError', () {
      final first =
          ErrorHandler.handle(const CloudMediaFileTooLargeException());
      final second = ErrorHandler.handle(first);
      expect(identical(first, second), isTrue);
    });
  });
}
