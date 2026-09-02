import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import '../constants/error_messages.dart';

// ─── Typed Exceptions ──────────────────────────────────────────────────────────
//
// Default messages reference ErrorMessages (the single source of truth for
// user-facing copy) rather than repeating hardcoded strings here — the two
// previously carried separately-worded text for the same concepts (e.g.
// this file said "Media permission denied." while ErrorMessages said
// "Permission denied. Please grant the required permissions.") with
// nothing keeping them in sync, and ErrorMessages itself was never
// actually referenced from anywhere.

class CloudMediaPermissionDeniedException implements Exception {
  final String message;
  const CloudMediaPermissionDeniedException(
      [this.message = ErrorMessages.permissionDenied]);
  @override
  String toString() => 'CloudMediaPermissionDeniedException: $message';
}

class CloudMediaPermissionPermanentlyDeniedException implements Exception {
  final String message;
  const CloudMediaPermissionPermanentlyDeniedException(
      [this.message = ErrorMessages.permissionPermanentlyDenied]);
  @override
  String toString() =>
      'CloudMediaPermissionPermanentlyDeniedException: $message';
}

class CloudMediaUnsupportedFileTypeException implements Exception {
  final String message;
  const CloudMediaUnsupportedFileTypeException(
      [this.message = ErrorMessages.unsupportedFileType]);
  @override
  String toString() => 'CloudMediaUnsupportedFileTypeException: $message';
}

class CloudMediaFileTooLargeException implements Exception {
  final String message;
  const CloudMediaFileTooLargeException(
      [this.message = ErrorMessages.fileTooLarge]);
  @override
  String toString() => 'CloudMediaFileTooLargeException: $message';
}

class CloudMediaUploadFailedException implements Exception {
  final String message;
  final dynamic originalError;
  const CloudMediaUploadFailedException(
      [this.message = ErrorMessages.uploadFailed, this.originalError]);
  @override
  String toString() => 'CloudMediaUploadFailedException: $message';
}

class CloudMediaOfflineQueueException implements Exception {
  final String message;
  final dynamic originalError;
  const CloudMediaOfflineQueueException(
      [this.message = 'Failed to queue offline operation.', this.originalError]);
  @override
  String toString() => 'CloudMediaOfflineQueueException: $message';
}

class CloudMediaSyncException implements Exception {
  final String message;
  final dynamic originalError;
  const CloudMediaSyncException(
      [this.message = 'Sync failed.', this.originalError]);
  @override
  String toString() => 'CloudMediaSyncException: $message';
}

class CloudMediaNetworkException implements Exception {
  final String message;
  const CloudMediaNetworkException(
      [this.message = ErrorMessages.networkError]);
  @override
  String toString() => 'CloudMediaNetworkException: $message';
}

class CloudMediaCompressionException implements Exception {
  final String message;
  const CloudMediaCompressionException(
      [this.message = ErrorMessages.compressionFailed]);
  @override
  String toString() => 'CloudMediaCompressionException: $message';
}

class CloudMediaThumbnailGenerationException implements Exception {
  final String message;
  const CloudMediaThumbnailGenerationException(
      [this.message = ErrorMessages.thumbnailFailed]);
  @override
  String toString() => 'CloudMediaThumbnailGenerationException: $message';
}

class CloudMediaBackgroundRemovalTimeoutException implements Exception {
  final String message;
  const CloudMediaBackgroundRemovalTimeoutException(
      [this.message = ErrorMessages.backgroundRemovalTimeout]);
  @override
  String toString() =>
      'CloudMediaBackgroundRemovalTimeoutException: $message';
}

/// Thrown when the input to [BackgroundRemovalService.removeBackground]
/// is invalid (empty path or the file doesn't exist) — distinct from
/// [CloudMediaBackgroundRemovalTimeoutException], which is specifically
/// about the on-device model taking too long, not a bad precondition.
class CloudMediaInvalidInputException implements Exception {
  final String message;
  const CloudMediaInvalidInputException([this.message = 'Invalid input.']);
  @override
  String toString() => 'CloudMediaInvalidInputException: $message';
}

class CloudMediaSelectionLimitExceededException implements Exception {
  final String message;
  // Deliberately keeps its own more specific default (mentions the
  // actual FileConstants.hardMaxSelection value) rather than
  // ErrorMessages.selectionLimitExceeded's generic text — Dart's const
  // defaults can't interpolate the constant's value in, so if
  // hardMaxSelection ever changes this literal needs updating by hand.
  const CloudMediaSelectionLimitExceededException(
      [this.message = 'Selection limit exceeded. Maximum is 100 files.']);
  @override
  String toString() => 'CloudMediaSelectionLimitExceededException: $message';
}

class CloudMediaNotFoundException implements Exception {
  final String message;
  const CloudMediaNotFoundException(
      [this.message = ErrorMessages.mediaNotFound]);
  @override
  String toString() => 'CloudMediaNotFoundException: $message';
}

// ─── Error Handler ─────────────────────────────────────────────────────────────

class CloudMediaError {
  final String code;
  final String message;
  final dynamic originalError;

  const CloudMediaError({
    required this.code,
    required this.message,
    this.originalError,
  });

  @override
  String toString() => 'CloudMediaError($code): $message';
}

class ErrorHandler {
  ErrorHandler._();

  static CloudMediaError handle(dynamic error) {
    if (error is CloudMediaError) return error;

    // The package's own typed exceptions already carry a clean,
    // user-facing message in their `message` field — without this
    // branch they fell through to the catch-all below, which uses
    // error.toString() and produces an ugly, class-name-prefixed
    // string (e.g. "CloudMediaPermissionDeniedException: ...") instead
    // of the clean text getUserFriendlyMessage is supposed to return.
    if (error is CloudMediaPermissionDeniedException) {
      return CloudMediaError(
          code: 'permission_denied', message: error.message, originalError: error);
    }
    if (error is CloudMediaPermissionPermanentlyDeniedException) {
      return CloudMediaError(
          code: 'permission_permanently_denied',
          message: error.message,
          originalError: error);
    }
    if (error is CloudMediaUnsupportedFileTypeException) {
      return CloudMediaError(
          code: 'unsupported_file_type', message: error.message, originalError: error);
    }
    if (error is CloudMediaFileTooLargeException) {
      return CloudMediaError(
          code: 'file_too_large', message: error.message, originalError: error);
    }
    if (error is CloudMediaUploadFailedException) {
      return CloudMediaError(
          code: 'upload_failed', message: error.message, originalError: error);
    }
    if (error is CloudMediaOfflineQueueException) {
      return CloudMediaError(
          code: 'offline_queue_error', message: error.message, originalError: error);
    }
    if (error is CloudMediaSyncException) {
      return CloudMediaError(
          code: 'sync_error', message: error.message, originalError: error);
    }
    if (error is CloudMediaNetworkException) {
      return CloudMediaError(
          code: 'network_error', message: error.message, originalError: error);
    }
    if (error is CloudMediaCompressionException) {
      return CloudMediaError(
          code: 'compression_failed', message: error.message, originalError: error);
    }
    if (error is CloudMediaThumbnailGenerationException) {
      return CloudMediaError(
          code: 'thumbnail_failed', message: error.message, originalError: error);
    }
    if (error is CloudMediaBackgroundRemovalTimeoutException) {
      return CloudMediaError(
          code: 'background_removal_timeout',
          message: error.message,
          originalError: error);
    }
    if (error is CloudMediaInvalidInputException) {
      return CloudMediaError(
          code: 'invalid_input', message: error.message, originalError: error);
    }
    if (error is CloudMediaSelectionLimitExceededException) {
      return CloudMediaError(
          code: 'selection_limit_exceeded',
          message: error.message,
          originalError: error);
    }
    if (error is CloudMediaNotFoundException) {
      return CloudMediaError(
          code: 'not_found', message: error.message, originalError: error);
    }

    if (error is SocketException) {
      return const CloudMediaError(
        code: 'network_error',
        message: 'No internet connection.',
      );
    }

    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return CloudMediaError(
            code: 'permission_denied',
            message: 'Firebase permission denied.',
            originalError: error,
          );
        case 'not-found':
          return CloudMediaError(
            code: 'not_found',
            message: 'Media not found.',
            originalError: error,
          );
        default:
          return CloudMediaError(
            code: error.code,
            message: error.message ?? 'Firebase error.',
            originalError: error,
          );
      }
    }

    return CloudMediaError(
      code: 'unknown_error',
      message: error.toString(),
      originalError: error,
    );
  }

  static String getUserFriendlyMessage(dynamic error) => handle(error).message;
  static bool isNetworkError(dynamic error) =>
      handle(error).code == 'network_error';
  static bool isPermissionError(dynamic error) {
    final code = handle(error).code;
    return code == 'permission_denied' || code == 'permission_permanently_denied';
  }
}
