import 'dart:io';

import 'package:dio/dio.dart';

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
      return UploadResult.fromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (e) {
      final mapped = e.error;
      if (mapped is AppNetworkException) {
        if (mapped.statusCode == 404) {
          throw Exception(
            'Govedo s odabranim zivotnim brojem nije pronadjeno.',
          );
        }
        if (mapped.statusCode == 400 && mapped.data != null) {
          throw Exception('Neispravan unos: ${mapped.data}');
        }
        throw Exception(mapped.message);
      }

      throw Exception('Upload nije uspio. Provjeri mrezu i pokusaj ponovno.');
    }
  }
}
