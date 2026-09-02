import 'package:cloud_media/services/offline_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

// OfflineSyncService itself wraps riverpod_offline_sync's real
// OfflineSyncLayer.instance / StorageQueue singletons, which need Hive
// storage, a connectivity monitor, and real Firebase to exercise
// meaningfully — that's integration-test territory (a real device or
// emulator, or riverpod_offline_sync's own test suite), not something
// to fake convincingly at the unit level here. What IS safely unit-
// testable in isolation is the pure QueuePriority → int mapping, which
// is what these tests cover.
void main() {
  group('QueuePriority.value', () {
    test('critical is the highest priority (lowest number)', () {
      expect(QueuePriority.critical.value, 0);
    });

    test('background is the lowest priority (highest number)', () {
      expect(QueuePriority.background.value, 4);
    });

    test('ordering is monotonic: critical < high < normal < low < background',
        () {
      expect(QueuePriority.critical.value, lessThan(QueuePriority.high.value));
      expect(QueuePriority.high.value, lessThan(QueuePriority.normal.value));
      expect(QueuePriority.normal.value, lessThan(QueuePriority.low.value));
      expect(
          QueuePriority.low.value, lessThan(QueuePriority.background.value));
    });

    test('every priority has a distinct value', () {
      final values = QueuePriority.values.map((p) => p.value).toSet();
      expect(values.length, QueuePriority.values.length);
    });
  });

  group('MediaUploadProgress', () {
    test('carries the fields it was constructed with', () {
      const progress = MediaUploadProgress(
        mediaId: 'm1',
        fraction: 0.5,
        bytesTransferred: 512,
        totalBytes: 1024,
      );

      expect(progress.mediaId, 'm1');
      expect(progress.fraction, 0.5);
      expect(progress.bytesTransferred, 512);
      expect(progress.totalBytes, 1024);
      expect(progress.isComplete, isFalse);
      expect(progress.isFailed, isFalse);
    });

    test('isComplete and isFailed default to false', () {
      const progress = MediaUploadProgress(
        mediaId: 'm1',
        fraction: 0,
        bytesTransferred: 0,
        totalBytes: 100,
      );
      expect(progress.isComplete, isFalse);
      expect(progress.isFailed, isFalse);
    });
  });

  // Regression coverage for the fix that made
  // CloudMediaWatcher.watchUploadProgress() actually work: previously
  // nothing wrote metadata.progress to Firestore at all, so it always
  // reported 0.0 then jumped to 1.0. The write itself needs a real
  // upload/Firebase in flight to exercise (see offline_sync_service.dart's
  // doc comments on why), but the throttling decision that gates it is
  // pure and fully testable here.
  group('shouldPersistProgress', () {
    test('true when progress has moved by at least the threshold', () {
      expect(
        shouldPersistProgress(fraction: 0.10, lastWritten: 0.0),
        isTrue,
      );
      expect(
        shouldPersistProgress(fraction: 0.55, lastWritten: 0.50),
        isTrue,
      );
    });

    test('false when progress has moved by less than the threshold', () {
      expect(
        shouldPersistProgress(fraction: 0.02, lastWritten: 0.0),
        isFalse,
      );
      expect(
        shouldPersistProgress(fraction: 0.53, lastWritten: 0.50),
        isFalse,
      );
    });

    test('true exactly at the threshold boundary', () {
      expect(
        shouldPersistProgress(fraction: 0.05, lastWritten: 0.0),
        isTrue,
      );
    });

    test('false for a fraction that goes backwards (should not happen in practice, but must not crash or misfire)',
        () {
      expect(
        shouldPersistProgress(fraction: 0.40, lastWritten: 0.50),
        isFalse,
      );
    });

    test('respects a custom threshold', () {
      expect(
        shouldPersistProgress(fraction: 0.15, lastWritten: 0.0, threshold: 0.2),
        isFalse,
      );
      expect(
        shouldPersistProgress(fraction: 0.25, lastWritten: 0.0, threshold: 0.2),
        isTrue,
      );
    });
  });
}
