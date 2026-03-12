import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../models/cattle.dart';

class CattleRepository {
  CattleRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  Future<List<Cattle>> fetchCattleByFarm(int farmId) async {
    final response = await _client.dio.get(
      '/api/gospodarstva/$farmId/animals/',
    );
    final data = response.data;

    List<dynamic> animalsRaw;
    if (data is Map<String, dynamic>) {
      final animals = data['animals'] ?? data['results'] ?? data['data'];
      if (animals is List) {
        animalsRaw = animals;
      } else {
        AppLogger.network(
          'Unexpected animals payload for farm=$farmId: ${data.runtimeType}',
        );
        return const <Cattle>[];
      }
    } else if (data is List) {
      animalsRaw = data;
    } else {
      AppLogger.network(
        'Unexpected animals response type for farm=$farmId: ${data.runtimeType}',
      );
      return const <Cattle>[];
    }

    final cattle = animalsRaw
        .whereType<Map>()
        .map((entry) => Cattle.fromApi(entry.cast<String, dynamic>()))
        .toList();

    AppLogger.network('Fetched cattle count=${cattle.length} for farm=$farmId');
    return cattle;
  }

  Future<Cattle> fetchCattleById(int cattleId) async {
    final response = await _client.dio.get('/api/goveda/goveda/$cattleId/');
    final data = response.data;

    if (data is Map<String, dynamic>) {
      return Cattle.fromApi(data);
    }

    AppLogger.network(
      'Unexpected cattle detail response type for id=$cattleId: ${data.runtimeType}',
    );
    throw StateError('Unexpected cattle detail payload for id=$cattleId');
  }
}
