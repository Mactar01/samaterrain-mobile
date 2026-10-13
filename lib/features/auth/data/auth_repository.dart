import 'package:dio/dio.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/network/dio_client.dart';

class AuthRepository {
  final Dio dio = DioClient().dio;

  Future<String?> login(String email, String password) async {
    try {
      final response = await dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        final token = response.data['token'];
        final role = response.data['user']['role'];
        
        await TokenStorage.saveSession(token, role);
        return role; // Return role instead of bool
      }
      return null;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      if (status == 429) {
        throw Exception('Trop de tentatives. Patientez une minute avant de réessayer.');
      }
      if (data is Map && data['errors'] is Map) {
        final details = (data['errors'] as Map).values.expand((v) => v is List ? v : [v]).join(' ');
        if (details.isNotEmpty) throw Exception(details);
      }
      if (data is Map && data['message'] != null) {
        throw Exception(data['message']);
      }
      throw Exception('Serveur injoignable (${e.type.name}). Vérifiez le WiFi et que le serveur tourne.');
    }
  }

  Future<String?> register(String name, String email, String phone, String password, String passwordConfirmation) async {
    try {
      final response = await dio.post('/auth/register', data: {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'password_confirmation': passwordConfirmation,
      });

      if (response.statusCode == 201) {
        final token = response.data['token'];
        final role = response.data['user']['role'];
        
        await TokenStorage.saveSession(token, role);
        return role;
      }
      return null;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data != null && data['errors'] != null) {
        final errors = data['errors'] as Map;
        final details = errors.values
            .expand((v) => v is List ? v : [v])
            .join(' ');
        throw Exception(details.isNotEmpty ? details : (data['message'] ?? "Erreur lors de l'inscription."));
      }
      if (data != null && data['message'] != null) {
        throw Exception(data['message']);
      }
      throw Exception("Erreur réseau: ${e.message ?? e.type}");
    } catch (e) {
      throw Exception("Erreur inattendue: $e");
    }
  }

  Future<void> logout() async {
    try {
      await dio.post('/auth/logout');
    } catch (e) {}
    await TokenStorage.clear();
  }
}
