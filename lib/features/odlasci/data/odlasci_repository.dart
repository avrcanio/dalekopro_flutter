import 'package:dio/dio.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_network_exception.dart';
import '../models/odlazak_models.dart';

class OdlasciRepository {
  OdlasciRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  String _basePath(int gospodarstvoId) =>
      '/api/odlasci/gospodarstvo/$gospodarstvoId/odlasci/';

  Future<List<OdlazakRecord>> fetchOdlasci(int gospodarstvoId) async {
    final response = await _client.dio.get<List<dynamic>>(
      _basePath(gospodarstvoId),
    );
    final data = response.data;
    if (data == null) {
      return const [];
    }
    return data
        .whereType<Map>()
        .map((e) => OdlazakRecord.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<OdlasciLookupData> fetchLookup(int gospodarstvoId) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      '${_basePath(gospodarstvoId)}lookup/',
    );
    final data = response.data;
    if (data == null) {
      return const OdlasciLookupData();
    }
    return OdlasciLookupData.fromJson(data);
  }

  Future<OdlazakRecord> createOdlazak(
    int gospodarstvoId,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        _basePath(gospodarstvoId),
        data: body,
        options: Options(extra: {'retryable': false}),
      );
      final data = response.data;
      if (data == null) {
        throw StateError('Prazan odgovor pri kreiranju odlaska.');
      }
      return OdlazakRecord.fromJson(data);
    } on DioException catch (e, stack) {
      AppLogger.network(
        'Odlazak create failed',
        error: e,
        stackTrace: stack,
      );
      throw _wrapDio(e);
    }
  }

  static Exception _wrapDio(DioException e) {
    final mapped = e.error;
    if (mapped is AppNetworkException) {
      final detail = _formatValidation(mapped.data);
      if (detail != null && detail.isNotEmpty) {
        return Exception(detail);
      }
      return Exception(mapped.message);
    }
    return Exception(e.message ?? 'Mrežna greška.');
  }

  static String? _formatValidation(Object? data) {
    if (data is! Map) {
      return null;
    }
    final buf = StringBuffer();
    for (final entry in data.entries) {
      final v = entry.value;
      if (v is List) {
        buf.writeln('${entry.key}: ${v.map((e) => e.toString()).join(' ')}');
      } else if (v is Map) {
        buf.writeln('${entry.key}: $v');
      } else {
        buf.writeln('${entry.key}: $v');
      }
    }
    final s = buf.toString().trim();
    return s.isEmpty ? null : s;
  }
}
