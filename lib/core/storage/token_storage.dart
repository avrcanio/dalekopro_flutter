import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  const TokenStorage();

  static const _secureStorage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _selectedFolderUriKey = 'selected_image_folder_uri';

  Future<void> saveToken(String token) =>
      _secureStorage.write(key: _tokenKey, value: token);

  Future<String?> readToken() => _secureStorage.read(key: _tokenKey);

  Future<void> clearSession() => _secureStorage.delete(key: _tokenKey);

  Future<void> saveFolderUri(String uri) =>
      _secureStorage.write(key: _selectedFolderUriKey, value: uri);

  Future<String?> readFolderUri() =>
      _secureStorage.read(key: _selectedFolderUriKey);
}
