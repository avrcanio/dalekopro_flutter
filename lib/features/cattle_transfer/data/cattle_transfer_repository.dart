import 'package:dio/dio.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_network_exception.dart';
import '../models/holding.dart';

class CattleTransferResult {
  const CattleTransferResult({
    required this.status,
    required this.gospodarstvoId,
    required this.originPosjedId,
    required this.destinationPosjedId,
    required this.movedCount,
    required this.govedaIds,
  });

  final String status;
  final int gospodarstvoId;
  final int originPosjedId;
  final int destinationPosjedId;
  final int movedCount;
  final List<int> govedaIds;

  factory CattleTransferResult.fromJson(Map<String, dynamic> json) {
    final rawIds = json['goveda_ids'];
    final ids = rawIds is List
        ? rawIds
              .map((item) => item is num ? item.toInt() : int.tryParse('$item'))
              .whereType<int>()
              .toList()
        : const <int>[];

    return CattleTransferResult(
      status: json['status']?.toString() ?? 'UNKNOWN',
      gospodarstvoId: (json['gospodarstvo_id'] as num?)?.toInt() ?? 0,
      originPosjedId: (json['origin_posjed_id'] as num?)?.toInt() ?? 0,
      destinationPosjedId:
          (json['destination_posjed_id'] as num?)?.toInt() ?? 0,
      movedCount: (json['moved_count'] as num?)?.toInt() ?? ids.length,
      govedaIds: ids,
    );
  }
}

class CattleTransferRepository {
  CattleTransferRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  static List<dynamic>? _extractHoldingsList(Object? data) {
    if (data is List) {
      return data;
    }
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final candidates = <dynamic>[
      data['results'],
      data['data'],
      data['posjedi'],
      data['items'],
      data['objects'],
      data['holdings'],
      data['gospodarstvo_posjedi'],
    ];

    for (final candidate in candidates) {
      if (candidate is List) {
        return candidate;
      }
    }

    final nestedCandidates = <dynamic>[
      data['data'],
      data['result'],
      data['payload'],
      data['response'],
      data['posjedi'],
      data['holdings'],
      data['gospodarstvo_posjedi'],
    ];

    for (final candidate in nestedCandidates) {
      final extracted = _extractHoldingsList(candidate);
      if (extracted != null) {
        return extracted;
      }
    }

    return null;
  }

  Future<List<Holding>> fetchHoldings(int farmId) async {
    final response = await _client.dio.get(
      '/api/gospodarstva/$farmId/posjedi/',
    );
    final data = response.data;

    final rawList = _extractHoldingsList(data);
    if (rawList == null) {
      AppLogger.network(
        'Unexpected holdings payload shape for farm=$farmId: ${data.runtimeType} data=$data',
      );
      return const <Holding>[];
    }

    final holdings = rawList
        .whereType<Map>()
        .map((item) => Holding.fromJson(item.cast<String, dynamic>()))
        .where((item) => item.id > 0 && item.label.isNotEmpty)
        .toList();

    if (holdings.isEmpty && rawList.isNotEmpty) {
      AppLogger.network(
        'Holdings payload mapped to empty list for farm=$farmId raw=$rawList',
      );
    }

    return holdings;
  }

  Future<CattleTransferResult> transferCattle({
    required int farmId,
    required int originId,
    required int destinationId,
    required List<int> cattleIds,
  }) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/api/goveda/transfer/',
        data: <String, dynamic>{
          'gospodarstvo_id': farmId,
          'origin_posjed_id': originId,
          'destination_posjed_id': destinationId,
          'goveda_ids': cattleIds,
        },
        options: Options(extra: {'retryable': false}),
      );

      final payload = response.data ?? <String, dynamic>{};
      final result = CattleTransferResult.fromJson(payload);
      if (result.status == 'UNKNOWN') {
        throw Exception('Neocekivan odgovor servera tijekom premjestanja.');
      }
      return result;
    } on DioException catch (e, stack) {
      AppLogger.network('Cattle transfer failed', error: e, stackTrace: stack);
      final mapped = e.error;
      if (mapped is AppNetworkException) {
        throw Exception(_messageFromStatus(mapped.statusCode, mapped.data));
      }

      throw Exception(
        _messageFromStatus(e.response?.statusCode, e.response?.data),
      );
    }
  }

  static String _messageFromStatus(int? statusCode, Object? data) {
    if (statusCode == 400) {
      final details = data?.toString();
      if (details != null && details.isNotEmpty) {
        return 'Neispravan zahtjev za premjestanje: $details';
      }
      return 'Neispravan zahtjev za premjestanje.';
    }
    if (statusCode == 401) {
      return 'Sesija nije valjana. Prijavi se ponovno.';
    }
    if (statusCode == 403) {
      return 'Nemate pravo premjestati goveda na ovom gospodarstvu.';
    }
    if (statusCode == 404) {
      return 'Trazeni resurs nije pronadjen.';
    }

    return 'Premjestanje nije uspjelo. Provjeri mrezu i pokusaj ponovno.';
  }
}
