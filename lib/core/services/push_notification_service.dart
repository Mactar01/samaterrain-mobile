import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../storage/token_storage.dart';
import '../network/dio_client.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

class PushNotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        // Ne pas afficher le jeton dans les logs (il permet d'envoyer des notifications à cet appareil)
        await _sendTokenToServer(token);
      }
    } else {
      print('User declined or has not accepted permission');
    }

    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      _sendTokenToServer(newToken);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
      }
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      final authToken = await TokenStorage.readToken();
      if (authToken != null && authToken.isNotEmpty) {
        await DioClient().dio.post(
          '/auth/fcm-token',
          data: {'fcm_token': token},
        );
      }
    } catch (e) {
      print("Erreur lors de l'envoi du token FCM: $e");
    }
  }
}
