import 'package:shared_preferences/shared_preferences.dart';
import 'session_store.dart';
import '../analytics/analytics_facade.dart';

/// ID del usuario que ha iniciado sesión, funciona sin conexión a internet, ya que el token está almacenado en el dispositivo.
  Future<String?> currentUserId() async {
      final preferences = await SharedPreferences.getInstance();

      final stored = preferences.getString(SessionStore.userIdKey);
      if (stored != null && stored.isNotEmpty) return stored;
      final token = preferences.getString('access_token');
      if (token == null || token.isEmpty) return null;
      return AnalyticsFacade.instance.decodeUserId(token);
}