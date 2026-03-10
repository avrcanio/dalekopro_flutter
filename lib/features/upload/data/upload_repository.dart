import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_network_exception.dart';

class UploadResult {
  const UploadResult({required this.status, required this.slikaId});

  final String status;
  final int? slikaId;

  factory UploadResult.fromJson(Map<String, dynamic> json) {
    return UploadResult(
      status: json['status']?.toString() ?? 'UNKNOWN',
      slikaId: (json['slika_id'] as num?)?.toInt(),
    );
  }
}

class UploadRepository {
  UploadRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  Future<UploadResult> uploadCattlePhoto({
    required String zivotniBroj,
    required File image,
    String? datum,
    double? latitude,
    double? longitude,
  }) async {
    final form = FormData.fromMap({
      'zivotni_broj': zivotniBroj,
      if (datum != null) 'datum': datum,
      if (latitude != null) 'latitude': latitude.toString(),
      if (longitude != null) 'longitude': longitude.toString(),
      'slika': await MultipartFile.fromFile(
        image.path,
        filename: image.uri.pathSegments.last,
      ),
    });

    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/api/slike_goveda/upload/',
        data: form,
        options: Options(extra: {'retryable': false}),
      );

      final payload = response.data ?? <String, dynamic>{};
      final result = UploadResult.fromJson(payload);
      if (result.status == 'UNKNOWN') {
        throw Exception('Neocekivan odgovor servera tijekom uploada.');
      }
      return result;
    } on DioException catch (e, stack) {
      AppLogger.network('Upload failed', error: e, stackTrace: stack);
      final mapped = e.error;
      if (mapped is AppNetworkException) {
        if (mapped.statusCode == 404) {
          throw Exception(
            'Govedo s odabranim zivotnim brojem nije pronadjeno.',
          );
        }
        if (mapped.statusCode == 400) {
          final details = mapped.data?.toString();
          if (details != null && details.isNotEmpty) {
            throw Exception('Neispravan unos: $details');
          }
          throw Exception('Neispravan unos podataka za upload.');
        }
        throw Exception(mapped.message);
      }

      final status = e.response?.statusCode;
      if (status == 404) {
        throw Exception('Govedo s odabranim zivotnim brojem nije pronadjeno.');
      }
      if (status == 400) {
        throw Exception('Neispravan unos podataka za upload.');
      }
      if (status == 401) {
        throw Exception('Sesija nije valjana. Prijavi se ponovno.');
      }

      throw Exception('Upload nije uspio. Provjeri mrezu i pokusaj ponovno.');
    }
  }
}
