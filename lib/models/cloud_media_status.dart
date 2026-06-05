import 'package:flutter/material.dart';

enum CloudMediaStatus {
  pending,
  processing,
  syncing,
  synced,
  failed,
  deleted,
}

extension CloudMediaStatusExtension on CloudMediaStatus {
  bool get isFinal =>
      this == CloudMediaStatus.synced ||
      this == CloudMediaStatus.failed ||
      this == CloudMediaStatus.deleted;

  bool get isUploading =>
      this == CloudMediaStatus.processing ||
      this == CloudMediaStatus.syncing;

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

  Color get color {
    switch (this) {
      case CloudMediaStatus.pending:
        return Colors.orange;
      case CloudMediaStatus.processing:
        return Colors.blue;
      case CloudMediaStatus.syncing:
        return Colors.purple;
      case CloudMediaStatus.synced:
        return Colors.green;
      case CloudMediaStatus.failed:
        return Colors.red;
      case CloudMediaStatus.deleted:
        return Colors.grey;
    }
  }
}
