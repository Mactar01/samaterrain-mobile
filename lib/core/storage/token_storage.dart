import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Session de l'utilisateur (jeton API + rôle), gardée en mémoire seulement.
///
/// L'app redemande la connexion à chaque lancement (le router démarre sur /login),
/// donc un jeton écrit sur le téléphone ne servait jamais à rouvrir la session.
/// Il restait en revanche après la déconnexion du processus : dans le Keychain iOS
/// même après désinstallation (l'appareil restait lié à l'ancien compte pour les
/// notifications), et illisible après une restauration de sauvegarde Android
/// (toutes les requêtes échouaient). En mémoire, il disparaît avec l'app.
class TokenStorage {
  static const _tokenKey = 'auth_token';
  static const _roleKey = 'user_role';

  static String? _token;
  static Future<void>? _cleanup;

  static Future<String?> readToken() async {
    await (_cleanup ??= _deleteStoredCopies());
    return _token;
  }

  static Future<void> saveSession(String token, String role) async {
    _token = token;
  }

  static Future<void> clear() async {
    _token = null;
  }

  /// Efface les jetons écrits par les versions précédentes de l'app :
  /// coffre sécurisé (Keystore / Keychain) et SharedPreferences en clair.
  /// Une erreur ici (coffre illisible après restauration) ne doit rien bloquer.
  static Future<void> _deleteStoredCopies() async {
    try {
      await const FlutterSecureStorage().deleteAll();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_roleKey);
      await prefs.remove('user'); // copie du profil, plus utilisée
    } catch (_) {}
  }
}
