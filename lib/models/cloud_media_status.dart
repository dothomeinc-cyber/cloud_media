import 'package:flutter/material.dart';

/// The sync status of a [CloudMediaItem].
///
/// Items transition through these states:
/// `pending → processing → syncing → synced`
///
/// On failure: `syncing → failed`
/// On deletion: `synced → deleted`
enum CloudMediaStatus {
  /// Item selected but not yet queued for upload.
  pending,

  /// Item is being compressed or thumbnails are being generated.
  processing,

  /// Item is currently uploading to Firebase Storage.
  syncing,

  /// Item has been successfully uploaded and synced.
  synced,

  /// Upload failed. Will retry automatically when connectivity returns.
  failed,

  /// Item has been soft-deleted.
  deleted,
}

/// Extension methods on [CloudMediaStatus].
extension CloudMediaStatusExtension on CloudMediaStatus {
  /// True if this status is a terminal state (no further transitions expected).
  bool get isFinal =>
      this == CloudMediaStatus.synced ||
      this == CloudMediaStatus.failed ||
      this == CloudMediaStatus.deleted;

  /// True if the item is currently being uploaded.
  bool get isUploading =>
      this == CloudMediaStatus.processing ||
      this == CloudMediaStatus.syncing;

  /// Human-readable display name for this status.
  String get displayName {
    switch (this) {
      case CloudMediaStatus.pending:
        return 'Pending';
      case CloudMediaStatus.processing:
        return 'Processing';
      case CloudMediaStatus.syncing:
        return 'Syncing';
      case CloudMediaStatus.synced:
        return 'Synced';
      case CloudMediaStatus.failed:
        return 'Failed';
      case CloudMediaStatus.deleted:
        return 'Deleted';
    }
  }

  /// Icon representing this status.
  IconData get icon {
    switch (this) {
      case CloudMediaStatus.pending:
        return Icons.hourglass_empty;
      case CloudMediaStatus.processing:
        return Icons.build;
      case CloudMediaStatus.syncing:
        return Icons.sync;
      case CloudMediaStatus.synced:
        return Icons.check_circle;
      case CloudMediaStatus.failed:
        return Icons.error;
      case CloudMediaStatus.deleted:
        return Icons.delete;
    }
  }

  /// Theme-aware color representing this status.
  Color statusColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (this) {
      case CloudMediaStatus.pending:
        return cs.tertiary;
      case CloudMediaStatus.processing:
        return cs.secondary;
      case CloudMediaStatus.syncing:
        return cs.primary;
      case CloudMediaStatus.synced:
        return cs.primary;
      case CloudMediaStatus.failed:
        return cs.error;
      case CloudMediaStatus.deleted:
        return cs.outline;
    }
  }
}
