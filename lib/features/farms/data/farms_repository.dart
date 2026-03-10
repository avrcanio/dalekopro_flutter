import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../models/farm.dart';

class FarmsRepository {
  FarmsRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  Future<List<Farm>> fetchFarms() async {
    final response = await _client.dio.get('/api/gospodarstva/');
    final data = response.data;

    List<dynamic> rawList;
    if (data is List) {
      rawList = data;
    } else if (data is Map<String, dynamic> && data['results'] is List) {
      rawList = data['results'] as List<dynamic>;
    } else {
      AppLogger.network('Unexpected farms payload shape: ${data.runtimeType}');
      return const <Farm>[];
    }

    final farms = rawList
        .whereType<Map>()
        .map((item) => Farm.fromJson(item.cast<String, dynamic>()))
        .toList();

    AppLogger.network('Fetched farms count=${farms.length}');
    return farms;
  }
}
