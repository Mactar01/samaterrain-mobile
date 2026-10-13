import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';

class FieldRepository {
  final Dio dio = DioClient().dio;

  Future<List<dynamic>> getFields({
    String? search,
    String? city,
    String? type,
    double? lat,
    double? lng,
    int? radius,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (city != null && city.isNotEmpty) queryParams['city'] = city;
      if (type != null && type.isNotEmpty && type != 'Tous') queryParams['type'] = type;
      if (lat != null && lng != null) {
        queryParams['lat'] = lat;
        queryParams['lng'] = lng;
        if (radius != null) queryParams['radius'] = radius;
      }

      final response = await dio.get('/fields', queryParameters: queryParams);
      if (response.statusCode == 200) {
        return response.data['data'] as List<dynamic>; 
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Détail d'un terrain : photos, équipements, contact du loueur.
  Future<Map<String, dynamic>> getField(int id) async {
    final response = await dio.get('/fields/$id');
    return Map<String, dynamic>.from(response.data['field']);
  }

  Future<List<dynamic>> getOwnerFields() async {
    try {
      final response = await dio.get('/owner/fields');
      if (response.statusCode == 200) {
        return response.data as List<dynamic>; 
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getFavorites() async {
    try {
      final response = await dio.get('/favorites');
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> addFavorite(int fieldId) async {
    await dio.post('/favorites', data: {'field_id': fieldId});
  }

  Future<void> removeFavorite(int fieldId) async {
    await dio.delete('/favorites/$fieldId');
  }
}
