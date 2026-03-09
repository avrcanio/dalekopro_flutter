import 'package:dio/dio.dart';

import 'app_network_exception.dart';

class ErrorMappingInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final mapped = _map(err);
    handler.reject(err.copyWith(error: mapped));
  }

  AppNetworkException _map(DioException err) {
    final status = err.response?.statusCode;
    final data = err.response?.data;

    if (status == 401) {
      return AppNetworkException(
        message: 'Sesija nije valjana. Prijavi se ponovno.',
        statusCode: status,
        data: data,
      );
    }

    if (status == 403) {
      return AppNetworkException(
        message: 'Nemate ovlasti za ovu radnju.',
        statusCode: status,
        data: data,
      );
    }

    if (status == 404) {
      return AppNetworkException(
        message: 'Trazeni resurs nije pronadjen.',
        statusCode: status,
        data: data,
      );
    }

    if (status == 400) {
      return AppNetworkException(
        message: 'Neispravan zahtjev.',
        statusCode: status,
        data: data,
      );
    }

    if (status != null && status >= 500) {
      return AppNetworkException(
        message: 'Server trenutno nije dostupan. Pokusaj ponovno.',
        statusCode: status,
        data: data,
      );
    }

    if (err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout) {
      return const AppNetworkException(
        message: 'Mrezna greska. Provjeri vezu i pokusaj ponovno.',
      );
    }

    return AppNetworkException(
      message: 'Neocekivana mrezna greska.',
      statusCode: status,
      data: data,
    );
  }
}
