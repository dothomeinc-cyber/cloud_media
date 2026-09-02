import 'package:cloud_media/services/offline_sync_service.dart';
import 'package:cloud_media/ui/widgets/upload_progress_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [child] the way a real consuming app would: ScreenUtilInit
/// (required — the widget under test uses .r/.w/.h/.sp) inside a
/// ProviderScope (required — the widget reads uploadProvider) inside a
/// MaterialApp (required for Theme.of/Icons/etc).
Widget _wrap(Widget child) {
  return ProviderScope(
    child: ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (context, _) => MaterialApp(home: Scaffold(body: child)),
    ),
  );
}

/// A plain in-memory [UploadControl] with no Firebase dependency at
/// all — used to make pause/resume/cancel/isUploading/isCancelled
/// testable without a real (or mocked) Firebase app existing.
///
/// Multiple attempts to get this working via `setupFirebaseCoreMocks()`
/// against the real `StorageQueue` each surfaced a genuinely new,
/// individually-verified Firebase-mocking issue in turn
/// ([core/no-app], [firebase_storage/no-bucket], [core/duplicate-app]
/// looping back to [firebase_storage/no-bucket] again) that traced back
/// to something outside any single test file registering a default
/// Firebase app with no options — not something fixable from within
/// this test without auditing test-runner/plugin-registration
/// internals this environment can't fully verify. Since none of
/// pause/resume/cancel/isUploading/isCancelled actually touch Firebase
/// Storage at all (confirmed against `StorageQueue`'s own source — only
/// uploadFile/deleteFile do), `OfflineSyncService.debugOverrideUploadControl`
/// was added as a narrower seam: it replaces just that in-memory
/// pause/cancel bookkeeping, sidestepping the Firebase-mocking problem
/// entirely rather than continuing to chase it.
class _FakeUploadControl implements UploadControl {
  final Set<String> _paused = {};
  final Set<String> _uploading = {};
  final Set<String> _cancelled = {};

  /// Test helper: mark [idempotencyKey] as currently uploading, the way
  /// a real in-flight [StorageQueue] upload would show up in
  /// [isUploading]. Call this before simulating a pause/cancel tap.
  void startUpload(String idempotencyKey) {
    _uploading.add(idempotencyKey);
    _paused.remove(idempotencyKey);
    _cancelled.remove(idempotencyKey);
  }

  @override
  void pauseUpload(String idempotencyKey) {
    if (_uploading.contains(idempotencyKey)) _paused.add(idempotencyKey);
  }

  @override
  void resumeUpload(String idempotencyKey) => _paused.remove(idempotencyKey);

  @override
  void cancelUpload(String idempotencyKey) {
    _uploading.remove(idempotencyKey);
    _paused.remove(idempotencyKey);
    _cancelled.add(idempotencyKey);
  }

  @override
  bool isUploading(String idempotencyKey) =>
      _uploading.contains(idempotencyKey);

  @override
  bool isCancelled(String idempotencyKey) =>
      _cancelled.contains(idempotencyKey);
}

void main() {
  group('UploadProgressIndicator — rendering (no Firebase needed)', () {
    // These two are safe without any Firebase setup: getProgress() only
    // reaches OfflineSyncService.watchUploadProgress, which touches a
    // plain in-memory Map, never the StorageQueue field that eagerly
    // evaluates FirebaseStorage.instance.
    testWidgets('renders without controls by default', (tester) async {
      await tester.pumpWidget(
        _wrap(const UploadProgressIndicator(mediaId: 'no_such_upload')),
      );
      await tester.pump();

      // No upload is actually in flight for this mediaId, so the
      // progress stream never emits and the widget shows its 0% idle
      // state rather than crashing — worth pinning on its own: a
      // widget that throws when there's simply nothing to show yet
      // would be a real regression.
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Uploading… 0%'), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('shows pause and cancel buttons when showControls is true',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const UploadProgressIndicator(
          mediaId: 'ctrl_upload',
          showControls: true,
        )),
      );
      await tester.pump();

      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });

  group('UploadProgressIndicator — pause/resume/cancel', () {
    late _FakeUploadControl fake;

    setUp(() {
      fake = _FakeUploadControl();
      OfflineSyncService.debugOverrideUploadControl(fake);
    });

    testWidgets(
      'tapping pause flips the icon to play_arrow and the label to Paused',
      (tester) async {
        fake.startUpload('upload_pause_upload');

        await tester.pumpWidget(
          _wrap(const UploadProgressIndicator(
            mediaId: 'pause_upload',
            showControls: true,
          )),
        );
        await tester.pump();

        await tester.tap(find.byIcon(Icons.pause));
        await tester.pump();

        expect(find.byIcon(Icons.play_arrow), findsOneWidget);
        expect(find.byIcon(Icons.pause), findsNothing);
        expect(find.text('Paused 0%'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping cancel invokes onCancelled',
      (tester) async {
        fake.startUpload('upload_cancel_upload');
        var cancelled = false;

        await tester.pumpWidget(
          _wrap(UploadProgressIndicator(
            mediaId: 'cancel_upload',
            showControls: true,
            onCancelled: () => cancelled = true,
          )),
        );
        await tester.pump();

        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();

        expect(cancelled, isTrue);
        expect(fake.isCancelled('upload_cancel_upload'), isTrue);
      },
    );
  });
}
