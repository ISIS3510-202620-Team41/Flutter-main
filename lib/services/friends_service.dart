import 'dart:convert';
import '../models/activity.dart';
import 'auth_service.dart';

class FriendsService {
  FriendsService({AuthService? authService})
      : _authService = authService ?? AuthService();

  final AuthService _authService;

  /// Llama a /friends/gaps,  el backend emite friend_availability_used (viewed).
  Future<List<FriendStatus>> loadAvailableFriends() async {
    final now = Uri.encodeQueryComponent(
      DateTime.now().toUtc().toIso8601String(),
    );
    final response = await _authService.authenticatedRequest(
      method: 'GET',
      path: '/friends/gaps?dateTime=$now',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, 'consultar la disponibilidad'));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('El servidor devolvió una respuesta inesperada al cargar los amigos.');
    }
    return decoded.map((item) {
      final json = Map<String, dynamic>.from(item as Map);
      final name = (json['name'] as String?)?.trim() ?? '';
      return FriendStatus(
        initials: _initials(name),
        name: name.isEmpty ? (json['email'] as String? ?? '') : name,
        email: json['email'] as String?,
        status: 'Libre',
      );
    }).toList(growable: false);
  }

  Future<void> sendRequest(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalizedEmail)) {
      throw Exception('Escribe un correo electrónico válido.');
    }

    final response = await _authService.authenticatedRequest(
      method: 'POST',
      path: '/friends/requests',
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'addresseeEmail': normalizedEmail}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, 'enviar la solicitud'));
    }
  }

  String _errorMessage(dynamic response, String action) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        for (final key in ['message', 'error', 'detail']) {
          final value = decoded[key];
          if (value is String && value.trim().isNotEmpty) return value.trim();
        }
      }
    } catch (_) {
      // El backend puede responder con texto plano o sin cuerpo.
    }
    return 'No se pudo $action (HTTP ${response.statusCode}).';
  }

  static String _initials(String name) {
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}