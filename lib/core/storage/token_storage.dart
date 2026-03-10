import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/app_user.dart';

class TokenStorage {
  const TokenStorage();

  static const _secureStorage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _selectedFolderUriKey = 'selected_image_folder_uri';
  static const _userIdKey = 'user_id';
  static const _usernameKey = 'user_username';
  static const _emailKey = 'user_email';
  static const _firstNameKey = 'user_first_name';
  static const _lastNameKey = 'user_last_name';

  Future<void> saveToken(String token) =>
      _secureStorage.write(key: _tokenKey, value: token);

  Future<String?> readToken() => _secureStorage.read(key: _tokenKey);

  Future<void> saveUser(AppUser user) async {
    await _secureStorage.write(key: _userIdKey, value: user.id.toString());
    await _secureStorage.write(key: _usernameKey, value: user.username);
    await _secureStorage.write(key: _emailKey, value: user.email);
    await _secureStorage.write(key: _firstNameKey, value: user.firstName);
    await _secureStorage.write(key: _lastNameKey, value: user.lastName);
  }

  Future<AppUser?> readUser() async {
    final values = await _secureStorage.readAll();
    final username = values[_usernameKey];
    if (username == null || username.isEmpty) {
      return null;
    }

    return AppUser(
      id: int.tryParse(values[_userIdKey] ?? '') ?? 0,
      username: username,
      email: values[_emailKey] ?? '',
      firstName: values[_firstNameKey] ?? '',
      lastName: values[_lastNameKey] ?? '',
    );
  }

  Future<void> clearSession() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _userIdKey);
    await _secureStorage.delete(key: _usernameKey);
    await _secureStorage.delete(key: _emailKey);
    await _secureStorage.delete(key: _firstNameKey);
    await _secureStorage.delete(key: _lastNameKey);
  }

  Future<void> saveFolderUri(String uri) =>
      _secureStorage.write(key: _selectedFolderUriKey, value: uri);

  Future<String?> readFolderUri() =>
      _secureStorage.read(key: _selectedFolderUriKey);
}
