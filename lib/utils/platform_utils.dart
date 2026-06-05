import 'dart:io';
import 'package:flutter/foundation.dart';

class PlatformUtils {
  PlatformUtils._();

  static bool get isWeb => kIsWeb;
  static bool get isMobile => !isWeb && (Platform.isIOS || Platform.isAndroid);
  static bool get isDesktop =>
      !isWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
  static bool get isIOS => !isWeb && Platform.isIOS;
  static bool get isAndroid => !isWeb && Platform.isAndroid;
  static bool get isMacOS => !isWeb && Platform.isMacOS;
  static bool get isWindows => !isWeb && Platform.isWindows;
  static bool get isLinux => !isWeb && Platform.isLinux;

  static String get platformName {
    if (isWeb) return 'Web';
    if (isIOS) return 'iOS';
    if (isAndroid) return 'Android';
    if (isMacOS) return 'macOS';
    if (isWindows) return 'Windows';
    if (isLinux) return 'Linux';
    return 'Unknown';
  }
}
