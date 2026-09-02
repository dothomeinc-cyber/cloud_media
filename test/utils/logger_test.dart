import 'package:cloud_media/utils/logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // CloudLogger just wraps debugPrint behind isEnabled/isDebugEnabled
  // flags — there's no return value to assert on, so these tests check
  // that toggling the flags doesn't throw and that the flags themselves
  // hold the value they were set to (the actual debugPrint output isn't
  // captured here; that's what the enableLogging regression test in
  // cloud_media_config_test.dart and the CloudMediaProvider.initialize()
  // wiring cover at the integration level).
  group('CloudLogger', () {
    // Restore defaults after each test so this file doesn't leak state
    // into other test files that might run in the same isolate.
    setUp(() {
      CloudLogger.isEnabled = true;
      CloudLogger.isDebugEnabled = true;
    });

    tearDown(() {
      CloudLogger.isEnabled = true;
      CloudLogger.isDebugEnabled = true;
    });

    test('info/debug/warning/error do not throw when enabled', () {
      expect(() => CloudLogger.info('test info'), returnsNormally);
      expect(() => CloudLogger.debug('test debug'), returnsNormally);
      expect(() => CloudLogger.warning('test warning'), returnsNormally);
      expect(() => CloudLogger.error('test error'), returnsNormally);
    });

    test('error accepts optional error and stackTrace without throwing', () {
      expect(
        () => CloudLogger.error(
          'test',
          error: Exception('inner'),
          stackTrace: StackTrace.current,
        ),
        returnsNormally,
      );
    });

    test('all methods are silent no-ops without throwing when isEnabled is false',
        () {
      CloudLogger.isEnabled = false;
      expect(() => CloudLogger.info('x'), returnsNormally);
      expect(() => CloudLogger.debug('x'), returnsNormally);
      expect(() => CloudLogger.warning('x'), returnsNormally);
      expect(() => CloudLogger.error('x'), returnsNormally);
    });

    test('debug is a no-op when isDebugEnabled is false even if isEnabled is true',
        () {
      CloudLogger.isEnabled = true;
      CloudLogger.isDebugEnabled = false;
      expect(() => CloudLogger.debug('x'), returnsNormally);
    });

    test('flags hold the value they were set to', () {
      CloudLogger.isEnabled = false;
      expect(CloudLogger.isEnabled, isFalse);
      CloudLogger.isEnabled = true;
      expect(CloudLogger.isEnabled, isTrue);
    });
  });
}
