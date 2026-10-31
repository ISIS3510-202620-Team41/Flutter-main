import 'package:shared_preferences/shared_preferences.dart';

// Almacenamiento de clave-valor para la sesión: tokens, ID de usuario y fecha/hora de la última sincronización.
class SessionStore {
  static const accessTokenKey = 'access_token';
  static const refreshTokenKey = 'refresh_token';
  static const userIdKey = 'user_id';
  static const lastSyncKey = 'last_sync_at';

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    String? userId,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(accessTokenKey, accessToken);
    await preferences.setString(refreshTokenKey, refreshToken);
    if (userId == null) {
      await preferences.remove(userIdKey);
    } else {
      await preferences.setString(userIdKey, userId);
    }
  }

  Future<String?> accessToken() async =>
      (await SharedPreferences.getInstance()).getString(accessTokenKey);

  Future<String?> userId() async =>
      (await SharedPreferences.getInstance()).getString(userIdKey);

  Future<DateTime?> lastSyncAt() async {
    final raw = (await SharedPreferences.getInstance()).getString(lastSyncKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> markSynced([DateTime? at]) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        lastSyncKey,
        (at ?? DateTime.now()).toUtc().toIso8601String(),
      );
    } catch (_) {
      // The timestamp is informative: it must never make a sync fail.
    }
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(accessTokenKey);
    await preferences.remove(refreshTokenKey);
    await preferences.remove(userIdKey);
    await preferences.remove(lastSyncKey);
  }
}