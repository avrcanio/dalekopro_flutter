import 'package:dio/dio.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_network_exception.dart';
import '../models/nedostatak_markica_record.dart';

class NedostatakMarkicaRepository {
  NedostatakMarkicaRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  static const String _path = '/api/markiranja/nedostatci/';

  /// Dohvaća sve stranice, zadržava zapise čiji je [govedo.id] u [govedoIds].
  Future<List<NedostatakMarkicaRecord>> fetchAllForFarmCattleIds(
    Set<int> govedoIds,
  ) async {
    if (govedoIds.isEmpty) {
      return const <NedostatakMarkicaRecord>[];
    }
    final all = <NedostatakMarkicaRecord>[];
    var page = 1;
    while (true) {
      final response = await _client.dio.get<Map<String, dynamic>>(
        _path,
        queryParameters: <String, dynamic>{'page': page},
      );
      final data = response.data;
      if (data == null) {
        break;
      }
      final results = data['results'];
      if (results is! List) {
        break;
      }
      for (final row in results.whereType<Map>()) {
        final r = NedostatakMarkicaRecord.fromJson(
          row.cast<String, dynamic>(),
        );
        if (r.id > 0 && govedoIds.contains(r.govedo.id)) {
          all.add(r);
        }
      }
      if (data['next'] == null) {
        break;
      }
      page++;
    }

    all.sort((a, b) {
      final da = a.datumPrijave ?? a.createdAt;
      final db = b.datumPrijave ?? b.createdAt;
      if (da != null && db != null) {
        final c = db.compareTo(da);
        if (c != 0) {
          return c;
        }
      }
      final ca = a.createdAt;
      final cb = b.createdAt;
      if (ca != null && cb != null) {
        return cb.compareTo(ca);
      }
      return b.id.compareTo(a.id);
    });

    return all;
  }

  Future<NedostatakMarkicaRecord> create(Map<String, dynamic> body) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        _path,
        data: body,
        options: Options(extra: {'retryable': false}),
      );
      final data = response.data;
      if (data == null) {
        throw StateError('Prazan odgovor pri kreiranju nedostatka markica.');
      }
      return NedostatakMarkicaRecord.fromJson(data);
    } on DioException catch (e, stack) {
      AppLogger.network(
        'Nedostatak markica create failed',
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
