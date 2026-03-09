import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';
import 'error_mapping_interceptor.dart';
import 'retry_interceptor.dart';

class ApiClient {
  ApiClient({required TokenStorage tokenStorage})
    : dio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: ApiConfig.connectTimeout,
          receiveTimeout: ApiConfig.receiveTimeout,
        ),
      ) {
    dio.interceptors.add(AuthInterceptor(tokenStorage));
    dio.interceptors.add(RetryInterceptor(dio: dio));
    dio.interceptors.add(ErrorMappingInterceptor());
  }

  final Dio dio;
}
