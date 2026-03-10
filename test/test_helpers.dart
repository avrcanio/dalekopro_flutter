import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void setupMockSecureStorage() {
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  final values = <String, String>{};

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorageChannel, (call) async {
        switch (call.method) {
          case 'read':
            return values[call.arguments['key'] as String? ?? ''];
          case 'write':
            values[call.arguments['key'] as String? ?? ''] =
                call.arguments['value'] as String? ?? '';
            return null;
          case 'readAll':
            return values;
          case 'writeAll':
            final input = (call.arguments as Map).cast<String, dynamic>();
            input.forEach((key, value) {
              values[key] = value?.toString() ?? '';
            });
            return null;
          case 'delete':
            values.remove(call.arguments['key'] as String? ?? '');
            return null;
          case 'deleteAll':
            values.clear();
            return null;
          default:
            return null;
        }
      });
}

void clearMockSecureStorage() {
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorageChannel, null);
}

void setupMockGeolocator() {
  const geolocatorChannel = MethodChannel('flutter.baseflow.com/geolocator');

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(geolocatorChannel, (call) async {
        switch (call.method) {
          case 'isLocationServiceEnabled':
            return false;
          case 'checkPermission':
            return 1; // denied
          case 'requestPermission':
            return 1; // denied
          default:
            return null;
        }
      });
}

void clearMockGeolocator() {
  const geolocatorChannel = MethodChannel('flutter.baseflow.com/geolocator');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(geolocatorChannel, null);
}
