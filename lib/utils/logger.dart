import 'package:flutter/foundation.dart';

class CloudLogger {
  CloudLogger._();

  static bool isEnabled = true;
  static bool isDebugEnabled = true;

  static void info(String message) {
    if (isEnabled) debugPrint('[CloudMedia INFO] $message');
  }

  static void debug(String message) {
    if (isEnabled && isDebugEnabled) debugPrint('[CloudMedia DEBUG] $message');
  }

  static void warning(String message) {
    if (isEnabled) debugPrint('[CloudMedia WARNING] $message');
  }

  static void error(String message,
      {dynamic error, StackTrace? stackTrace}) {
    if (!isEnabled) return;
    debugPrint('[CloudMedia ERROR] $message');
    if (error != null) debugPrint('  ↳ $error');
    if (stackTrace != null) debugPrint('  ↳ $stackTrace');
  }
}
