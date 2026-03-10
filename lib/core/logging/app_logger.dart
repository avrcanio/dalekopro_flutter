import 'package:flutter/foundation.dart';

class AppLogger {
  const AppLogger._();

  static void network(String message, {Object? error, StackTrace? stackTrace}) {
    debugPrint('[network] $message');
    if (error != null) {
      debugPrint('[network] error: $error');
    }
    if (stackTrace != null) {
      debugPrint('[network] stack: $stackTrace');
    }
  }
}
