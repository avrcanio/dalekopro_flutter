import 'dart:async';

import 'package:dio/dio.dart';

class RetryInterceptor extends Interceptor {
  RetryInterceptor({required Dio dio, this.maxRetries = 2}) : _dio = dio;

  final Dio _dio;
  final int maxRetries;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_shouldRetry(err)) {
      handler.next(err);
      return;
    }

    final options = err.requestOptions;
    final currentRetry = (options.extra['retry_count'] as int?) ?? 0;

    if (currentRetry >= maxRetries) {
      handler.next(err);
      return;
    }

    final nextRetry = currentRetry + 1;
    options.extra['retry_count'] = nextRetry;

    await Future<void>.delayed(Duration(milliseconds: 300 * nextRetry));

    try {
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  bool _shouldRetry(DioException err) {
    final method = err.requestOptions.method.toUpperCase();
    final retryableMethod =
        method == 'GET' || method == 'HEAD' || method == 'OPTIONS';
    final explicitlyRetryable = err.requestOptions.extra['retryable'] == true;
    if (!retryableMethod && !explicitlyRetryable) {
      return false;
    }

    if (err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout) {
      return true;
    }

    final status = err.response?.statusCode;
    return status != null && status >= 500;
  }
}
