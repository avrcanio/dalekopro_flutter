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
    if (data is! Map<String, dynamic>) {
      return const <Cattle>[];
    }

    final animals = data['animals'];
    if (animals is! List) {
      return const <Cattle>[];
    }

    return animals
        .whereType<Map>()
        .map((entry) => Cattle.fromApi(entry.cast<String, dynamic>()))
        .toList();
  }
}
