import '../../../core/network/api_client.dart';
import '../models/farm.dart';

class FarmsRepository {
  FarmsRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  Future<List<Farm>> fetchFarms() async {
    final response = await _client.dio.get('/api/gospodarstva/');
    final data = response.data;
    if (data is! List) {
      return const <Farm>[];
    }
    return data
        .whereType<Map>()
        .map((item) => Farm.fromJson(item.cast<String, dynamic>()))
        .toList();
  }
}
