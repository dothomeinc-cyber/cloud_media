import 'dart:io';
import 'package:firebase_core/firebase_core.dart';

// ─── Typed Exceptions ──────────────────────────────────────────────────────────

class CloudMediaPermissionDeniedException implements Exception {
  final String message;
  const CloudMediaPermissionDeniedException(
      [this.message = 'Media permission denied.']);
  @override
  String toString() => 'CloudMediaPermissionDeniedException: $message';
}

class CloudMediaPermissionPermanentlyDeniedException implements Exception {
  final String message;
  const CloudMediaPermissionPermanentlyDeniedException(
      [this.message = 'Permission permanently denied. Open app settings.']);
  @override
  String toString() =>
      'CloudMediaPermissionPermanentlyDeniedException: $message';
}

class CloudMediaUnsupportedFileTypeException implements Exception {
  final String message;
  const CloudMediaUnsupportedFileTypeException(
      [this.message = 'Unsupported file type.']);
  @override
  String toString() => 'CloudMediaUnsupportedFileTypeException: $message';
}

class CloudMediaFileTooLargeException implements Exception {
  final String message;
  const CloudMediaFileTooLargeException(
      [this.message = 'File exceeds maximum allowed size.']);
  @override
  String toString() => 'CloudMediaFileTooLargeException: $message';
}

class CloudMediaUploadFailedException implements Exception {
  final String message;
  final dynamic originalError;
  const CloudMediaUploadFailedException(
      [this.message = 'Upload failed.', this.originalError]);
  @override
  String toString() => 'CloudMediaUploadFailedException: $message';
}

class CloudMediaOfflineQueueException implements Exception {
  final String message;
  const CloudMediaOfflineQueueException(
      [this.message = 'Failed to queue offline operation.']);
  @override
  String toString() => 'CloudMediaOfflineQueueException: $message';
}

class CloudMediaSyncException implements Exception {
  final String message;
  const CloudMediaSyncException([this.message = 'Sync failed.']);
  @override
  String toString() => 'CloudMediaSyncException: $message';
}

class CloudMediaNetworkException implements Exception {
  final String message;
  const CloudMediaNetworkException(
      [this.message = 'Network error. Check your connection.']);
  @override
  String toString() => 'CloudMediaNetworkException: $message';
}

class CloudMediaCompressionException implements Exception {
  final String message;
  const CloudMediaCompressionException(
      [this.message = 'Image compression failed.']);
  @override
  String toString() => 'CloudMediaCompressionException: $message';
}

class CloudMediaThumbnailGenerationException implements Exception {
  final String message;
  const CloudMediaThumbnailGenerationException(
      [this.message = 'Thumbnail generation failed.']);
  @override
  String toString() => 'CloudMediaThumbnailGenerationException: $message';
}

class CloudMediaBackgroundRemovalTimeoutException implements Exception {
  final String message;
  const CloudMediaBackgroundRemovalTimeoutException(
      [this.message = 'Background removal timed out.']);
  @override
  String toString() =>
      'CloudMediaBackgroundRemovalTimeoutException: $message';
}

class CloudMediaSelectionLimitExceededException implements Exception {
  final String message;
  const CloudMediaSelectionLimitExceededException(
      [this.message = 'Selection limit exceeded. Maximum is 100 files.']);
  @override
  String toString() => 'CloudMediaSelectionLimitExceededException: $message';
}

class CloudMediaNotFoundException implements Exception {
  final String message;
  const CloudMediaNotFoundException([this.message = 'Media not found.']);
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
  static bool isPermissionError(dynamic error) =>
      handle(error).code == 'permission_denied';
}
