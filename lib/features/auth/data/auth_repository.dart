import 'package:dio/dio.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/models/app_user.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_network_exception.dart';
import '../../../core/storage/token_storage.dart';

class LoginResult {
  const LoginResult({required this.token, required this.user});

  final String token;
  final AppUser user;
}

class AuthRepository {
  AuthRepository({
    required ApiClient client,
    required TokenStorage tokenStorage,
  }) : _client = client,
       _tokenStorage = tokenStorage;

  final ApiClient _client;
  final TokenStorage _tokenStorage;

  Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/api/auth/login/',
        data: {'username': username, 'password': password},
      );

      final data = response.data ?? <String, dynamic>{};
      final token = data['token']?.toString();
      if (token == null || token.isEmpty) {
        throw Exception('Server nije vratio token.');
      }

      final user = AppUser.fromJson(
        (data['user'] as Map?)?.cast<String, dynamic>() ?? {},
      );

      await _tokenStorage.saveToken(token);
      await _tokenStorage.saveUser(user);

      return LoginResult(token: token, user: user);
    } on DioException catch (e, stack) {
      AppLogger.network('Auth login failed', error: e, stackTrace: stack);
      final mapped = e.error;
      if (mapped is AppNetworkException) {
        if (mapped.statusCode == 401) {
          throw Exception('Neispravno korisnicko ime ili lozinka.');
        }
        if (mapped.statusCode == 400) {
          throw Exception('Neispravan zahtjev. Provjeri unesene podatke.');
        }
        throw Exception(mapped.message);
      }

      final status = e.response?.statusCode;
      if (status == 401) {
        throw Exception('Neispravno korisnicko ime ili lozinka.');
      }
      if (status == 400) {
        throw Exception('Neispravan zahtjev. Provjeri unesene podatke.');
      }

      throw Exception('Mrezna greska tijekom prijave.');
    }
  }
}
