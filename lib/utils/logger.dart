class CloudLogger {
  CloudLogger._();

  static bool isEnabled = true;
  static bool isDebugEnabled = true;

  static void info(String message) {
    if (isEnabled) print('[CloudMedia INFO] $message');
  }

  static void debug(String message) {
    if (isEnabled && isDebugEnabled) print('[CloudMedia DEBUG] $message');
  }

  static void warning(String message) {
    if (isEnabled) print('[CloudMedia WARNING] $message');
  }

  static void error(String message,
      {dynamic error, StackTrace? stackTrace}) {
    if (!isEnabled) return;
    print('[CloudMedia ERROR] $message');
    if (error != null) print('  ↳ $error');
    if (stackTrace != null) print('  ↳ $stackTrace');
  }
}
