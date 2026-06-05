class ErrorMessages {
  ErrorMessages._();

  static const String notInitialized =
      'CloudMedia not initialized. Call CloudMedia.initialize() first.';
  static const String permissionDenied =
      'Permission denied. Please grant the required permissions.';
  static const String permissionPermanentlyDenied =
      'Permission permanently denied. Please enable it in app settings.';
  static const String networkError =
      'Network error. Please check your internet connection.';
  static const String uploadFailed = 'Upload failed. Please try again.';
  static const String downloadFailed = 'Download failed. Please try again.';
  static const String mediaNotFound = 'Media not found.';
  static const String unsupportedFileType =
      'File type not supported. Please select a valid file.';
  static const String fileTooLarge = 'File exceeds the maximum allowed size.';
  static const String selectionLimitExceeded =
      'Maximum file selection limit exceeded.';
  static const String backgroundRemovalTimeout =
      'Background removal timed out. You can retry or continue with the original.';
  static const String compressionFailed =
      'Image compression failed. Using original file.';
  static const String thumbnailFailed = 'Thumbnail generation failed.';
}
