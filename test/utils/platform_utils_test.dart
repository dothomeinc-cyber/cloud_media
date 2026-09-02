import 'package:cloud_media/utils/platform_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // These run on the test host's actual platform (Linux/macOS/Windows in
  // CI, whatever the dev machine is locally), so assertions are about
  // internal consistency between the getters — not about which specific
  // platform is true — since that varies by where the test runs.
  group('PlatformUtils internal consistency', () {
    test('exactly one of the OS-family booleans matches, unless web', () {
      final osFlags = [
        PlatformUtils.isIOS,
        PlatformUtils.isAndroid,
        PlatformUtils.isMacOS,
        PlatformUtils.isWindows,
        PlatformUtils.isLinux,
      ];
      if (PlatformUtils.isWeb) {
        expect(osFlags.every((f) => f == false), isTrue,
            reason: 'On web, no dart:io Platform getter should read true.');
      } else {
        expect(osFlags.where((f) => f).length, 1,
            reason: 'Exactly one OS family should be true off-web.');
      }
    });

    test('isMobile is true iff iOS or Android, and false on web', () {
      if (PlatformUtils.isWeb) {
        expect(PlatformUtils.isMobile, isFalse);
      } else {
        expect(PlatformUtils.isMobile,
            PlatformUtils.isIOS || PlatformUtils.isAndroid);
      }
    });

    test('isDesktop is true iff macOS, Windows, or Linux, and false on web',
        () {
      if (PlatformUtils.isWeb) {
        expect(PlatformUtils.isDesktop, isFalse);
      } else {
        expect(
          PlatformUtils.isDesktop,
          PlatformUtils.isMacOS ||
              PlatformUtils.isWindows ||
              PlatformUtils.isLinux,
        );
      }
    });

    test('isMobile and isDesktop are never both true', () {
      expect(PlatformUtils.isMobile && PlatformUtils.isDesktop, isFalse);
    });

    test('platformName matches the true flag', () {
      final name = PlatformUtils.platformName;
      if (PlatformUtils.isWeb) {
        expect(name, 'Web');
      } else if (PlatformUtils.isIOS) {
        expect(name, 'iOS');
      } else if (PlatformUtils.isAndroid) {
        expect(name, 'Android');
      } else if (PlatformUtils.isMacOS) {
        expect(name, 'macOS');
      } else if (PlatformUtils.isWindows) {
        expect(name, 'Windows');
      } else if (PlatformUtils.isLinux) {
        expect(name, 'Linux');
      } else {
        expect(name, 'Unknown');
      }
    });

    test('platformName is never empty', () {
      expect(PlatformUtils.platformName, isNotEmpty);
    });
  });
}
