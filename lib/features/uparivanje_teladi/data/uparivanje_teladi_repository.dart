import 'package:dio/dio.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_network_exception.dart';
import '../models/parent_candidate.dart';
import '../models/uparivanje_telad.dart';

class UparivanjeTeladiRepository {
  UparivanjeTeladiRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  Future<List<UparivanjeTelad>> fetchList(int gospodarstvoId) async {
    final response = await _client.dio.get<dynamic>(
      '/api/markiranja/gospodarstva/$gospodarstvoId/uparivanja-teladi/',
    );
    final data = response.data;
    if (data is! List) {
      AppLogger.network(
        'Unexpected uparivanja list shape: ${data.runtimeType}',
      );
      return const <UparivanjeTelad>[];
    }
    return data
        .whereType<Map>()
        .map((row) => UparivanjeTelad.fromJson(row.cast<String, dynamic>()))
        .where((e) => e.id > 0)
        .toList();
  }

  Future<UparivanjeTelad> fetchDetail(int gospodarstvoId, int id) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      '/api/markiranja/gospodarstva/$gospodarstvoId/uparivanja-teladi/$id/',
    );
    final data = response.data;
    if (data == null) {
      throw StateError('Prazan odgovor za detalj uparivanja.');
    }
    return UparivanjeTelad.fromJson(data);
  }

  Future<UparivanjeTelad> create(
    int gospodarstvoId,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/api/markiranja/gospodarstva/$gospodarstvoId/uparivanja-teladi/',
        data: body,
        options: Options(extra: {'retryable': false}),
      );
      final data = response.data;
      if (data == null) {
        throw StateError('Prazan odgovor pri kreiranju.');
      }
      return UparivanjeTelad.fromJson(data);
    } on DioException catch (e, stack) {
      AppLogger.network('Uparivanje create failed', error: e, stackTrace: stack);
      throw _wrapDio(e);
    }
  }

  Future<UparivanjeTelad> update(
    int gospodarstvoId,
    int id,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client.dio.patch<Map<String, dynamic>>(
        '/api/markiranja/gospodarstva/$gospodarstvoId/uparivanja-teladi/$id/',
        data: body,
        options: Options(extra: {'retryable': false}),
      );
      final data = response.data;
      if (data == null) {
        throw StateError('Prazan odgovor pri izmjeni.');
      }
      return UparivanjeTelad.fromJson(data);
    } on DioException catch (e, stack) {
      AppLogger.network('Uparivanje patch failed', error: e, stackTrace: stack);
      throw _wrapDio(e);
    }
  }

  Future<void> delete(int gospodarstvoId, int id) async {
    try {
      await _client.dio.delete<void>(
        '/api/markiranja/gospodarstva/$gospodarstvoId/uparivanja-teladi/$id/',
        options: Options(extra: {'retryable': false}),
      );
    } on DioException catch (e, stack) {
      AppLogger.network('Uparivanje delete failed', error: e, stackTrace: stack);
      throw _wrapDio(e);
    }
  }

  Future<List<ParentCandidate>> searchMajke(
    int gospodarstvoId,
    int posjedVezaId,
    String query,
  ) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      '/api/markiranja/gospodarstva/$gospodarstvoId/posjedi/$posjedVezaId/kandidati-majke/',
      queryParameters: <String, dynamic>{'q': query},
    );
    return _parseResults(response.data);
  }

  Future<List<ParentCandidate>> searchBikovi(
    int gospodarstvoId,
    String query,
  ) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      '/api/markiranja/gospodarstva/$gospodarstvoId/kandidati-bikovi/',
      queryParameters: <String, dynamic>{'q': query},
    );
    return _parseResults(response.data);
  }

  static List<ParentCandidate> _parseResults(Map<String, dynamic>? data) {
    if (data == null) {
      return const <ParentCandidate>[];
    }
    final raw = data['results'];
    if (raw is! List) {
      return const <ParentCandidate>[];
    }
    return raw
        .whereType<Map>()
        .map((m) => ParentCandidate.fromJsonMap(m.cast<String, dynamic>()))
        .whereType<ParentCandidate>()
        .toList();
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
    return Exception(e.message ?? 'Mrezna greska.');
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
