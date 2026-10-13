import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../storage/token_storage.dart';
import '../router/app_router.dart';

class DioClient {
  static final DioClient _instance = DioClient._internal();
  late final Dio dio;

  factory DioClient() {
    return _instance;
  }

  // Adresse du serveur (sans /api/v1), aussi utilisée pour les images.
  // Définie dynamiquement par --dart-define=API_URL=...
  // - develop : 'http://127.0.0.1:8000' (téléphone branché en USB + `adb reverse tcp:8000 tcp:8000`)
  // - preprod : 'http://165.232.65.22:8000'
  // - prod    : 'https://api.myterrain.sn'
  static const String _defaultUrl = kReleaseMode
      ? 'http://165.232.65.22:8000'
      : 'http://127.0.0.1:8000';

  static const String serverUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: _defaultUrl,
  );

  DioClient._internal() {
    const String baseUrl = '$serverUrl/api/v1';

    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 45),
      receiveTimeout: const Duration(seconds: 45),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Pas de jeton sur la connexion / l'inscription : il appartiendrait à une autre session.
          final isAuthCall = options.path.startsWith('/auth/login') ||
              options.path.startsWith('/auth/register');
          final token = isAuthCall ? null : await TokenStorage.readToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // Session expirée : on oublie le token et on renvoie au login.
          // (Un 401 sur /auth/login = mauvais identifiants, pas une session expirée.)
          final isLoginCall = error.requestOptions.path.startsWith('/auth/login');
          if (error.response?.statusCode == 401 && !isLoginCall) {
            await TokenStorage.clear();
            appRouter.go('/login');
          }
          return handler.next(error);
        },
      ),
    );
  }
}
