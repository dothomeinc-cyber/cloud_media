import 'package:cloud_media/api/cloud_media_watch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // CloudMediaWatcher's methods (watchMultiple, watchWithStatusFilter,
  // watchUntil, watchStatus, watchUploadProgress) all call
  // CloudMedia.watch() directly with no injection seam — same
  // Firebase-initialization constraint documented throughout this
  // package's other tests, so they aren't unit-testable here. What IS
  // testable without any dependency is dispose()'s own behavior on an
  // otherwise-untouched instance.
  group('CloudMediaWatcher.dispose', () {
    test('is safe to call on a freshly-constructed instance with nothing tracked',
        () {
      final watcher = CloudMediaWatcher();
      expect(watcher.dispose, returnsNormally);
    });

    test('is safe to call more than once', () {
      final watcher = CloudMediaWatcher();
      watcher.dispose();
      expect(watcher.dispose, returnsNormally);
    });
  });
}
