import 'package:flutter/services.dart';

/// Android: reads a one-shot path written by MainActivity after ACTION_SEND (share image).
class ShareIntentBridge {
  ShareIntentBridge._();

  static const MethodChannel _channel = MethodChannel('dalekopro/share');

  static Future<String?> consumePendingSharePath() async {
    try {
      final path = await _channel.invokeMethod<String>('consumePendingSharePath');
      return path;
    } on MissingPluginException {
      return null;
    }
  }
}
