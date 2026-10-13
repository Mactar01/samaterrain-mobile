import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';

/// Appels API de l'espace loueur. Chaque méthode lève une Exception avec un message lisible en cas d'erreur.
class OwnerRepository {
  final Dio dio = DioClient().dio;

  Future<T> _call<T>(Future<T> Function() request, String fallback) async {
    try {
      return await request();
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['errors'] is Map) {
        final details = (data['errors'] as Map).values.expand((v) => v is List ? v : [v]).join(' ');
        if (details.isNotEmpty) throw Exception(details);
      }
      if (data is Map && data['message'] != null) {
        throw Exception(data['message']);
      }
      throw Exception(fallback);
    }
  }

  // ─── Tableau de bord ───
  Future<Map<String, dynamic>> getDashboard() => _call(() async {
        final response = await dio.get('/owner/dashboard');
        return Map<String, dynamic>.from(response.data);
      }, 'Impossible de charger le tableau de bord.');

  // ─── Réservations ───
  Future<List<dynamic>> getReservations() => _call(() async {
        final response = await dio.get('/owner/reservations');
        return response.data is Map ? (response.data['data'] as List<dynamic>) : <dynamic>[];
      }, 'Impossible de charger les réservations.');

  Future<void> confirmReservation(int id) =>
      _call(() => dio.patch('/reservations/$id/confirm'), 'Impossible de confirmer la réservation.');

  Future<void> cancelReservation(int id) =>
      _call(() => dio.put('/reservations/$id/cancel'), "Impossible d'annuler la réservation.");

  Future<void> createManualReservation(int slotId, String playerName, String playerPhone) => _call(
        () => dio.post('/owner/reservations/manual', data: {
          'time_slot_id': slotId,
          'player_name': playerName,
          'player_phone': playerPhone,
        }),
        "Impossible d'enregistrer la réservation.",
      );

  // ─── Terrains ───
  Future<Map<String, dynamic>> getField(int id) => _call(() async {
        final response = await dio.get('/fields/$id');
        final data = response.data;
        return Map<String, dynamic>.from(data is Map && data['field'] is Map ? data['field'] : data);
      }, 'Impossible de charger le terrain.');

  /// Crée le terrain et renvoie son id.
  Future<int> createField(Map<String, dynamic> data) => _call(() async {
        final response = await dio.post('/fields', data: data);
        return response.data['field']['id'] as int;
      }, 'Impossible de créer le terrain.');

  Future<void> updateField(int id, Map<String, dynamic> data) =>
      _call(() => dio.put('/fields/$id', data: data), 'Impossible de modifier le terrain.');

  Future<void> uploadFieldImage(int fieldId, String filePath, {bool isPrimary = false}) => _call(() async {
        final form = FormData.fromMap({
          'image': await MultipartFile.fromFile(filePath, filename: filePath.split(RegExp(r'[\\/]')).last),
          if (isPrimary) 'is_primary': 1,
        });
        await dio.post(
          '/fields/$fieldId/images',
          data: form,
          options: Options(contentType: 'multipart/form-data; boundary=${form.boundary}', sendTimeout: const Duration(minutes: 2)),
        );
      }, "Impossible d'envoyer la photo.");

  Future<void> deleteFieldImage(int fieldId, int imageId) =>
      _call(() => dio.delete('/fields/$fieldId/images/$imageId'), 'Impossible de supprimer la photo.');

  Future<void> setPrimaryImage(int fieldId, int imageId) =>
      _call(() => dio.patch('/fields/$fieldId/images/$imageId/primary'), 'Impossible de changer la photo principale.');

  // ─── Créneaux ───
  Future<List<dynamic>> getSlots(int fieldId, String date) => _call(() async {
        final response = await dio.get('/fields/$fieldId/slots', queryParameters: {'date': date});
        return response.data as List<dynamic>;
      }, 'Impossible de charger les créneaux.');

  Future<void> createSlot(int fieldId, {required String date, required String startTime, required String endTime, double? price}) =>
      _call(
        () => dio.post('/fields/$fieldId/slots', data: {
          'date': date,
          'start_time': startTime,
          'end_time': endTime,
          if (price != null) 'price': price,
        }),
        "Impossible d'ajouter le créneau.",
      );

  /// Génère des créneaux sur une période. Renvoie le message du serveur (ex : "12 créneaux générés").
  Future<String> bulkCreateSlots(
    int fieldId, {
    required String startDate,
    required String endDate,
    required String startTime,
    required String endTime,
    required int durationMinutes,
    double? price,
  }) =>
      _call(() async {
        final response = await dio.post('/fields/$fieldId/slots/bulk', data: {
          'start_date': startDate,
          'end_date': endDate,
          'start_time': startTime,
          'end_time': endTime,
          'duration_minutes': durationMinutes,
          if (price != null) 'price': price,
        });
        return (response.data['message'] ?? 'Créneaux générés.').toString();
      }, 'Impossible de générer les créneaux.');

  Future<void> setSlotBlocked(int fieldId, int slotId, bool blocked) => _call(
        () => dio.put('/fields/$fieldId/slots/$slotId', data: {'status': blocked ? 'blocked' : 'available'}),
        'Impossible de modifier le créneau.',
      );

  Future<void> deleteSlot(int fieldId, int slotId) =>
      _call(() => dio.delete('/fields/$fieldId/slots/$slotId'), 'Impossible de supprimer le créneau.');
}
