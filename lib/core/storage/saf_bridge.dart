import 'package:flutter/services.dart';

class SafBridge {
  const SafBridge();

  static const MethodChannel _channel = MethodChannel('dalekopro/saf');

  Future<String?> selectDocumentTree({String? initialTreeUri}) async {
    final response = await _channel.invokeMapMethod<String, dynamic>(
      'selectDocumentTree',
      <String, dynamic>{'initialTreeUri': initialTreeUri},
    );
    return response?['treeUri']?.toString();
  }

  Future<String?> pickImageFromTree({required String treeUri}) async {
    final response = await _channel.invokeMapMethod<String, dynamic>(
      'pickImageFromTree',
      <String, dynamic>{'treeUri': treeUri},
    );
    return response?['filePath']?.toString();
  }
}
