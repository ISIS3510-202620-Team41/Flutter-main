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
      throw Exception('No se pudo consultar la disponibilidad de amigos');
    }

    final decoded = jsonDecode(response.body) as List<dynamic>;
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
    final response = await _authService.authenticatedRequest(
      method: 'POST',
      path: '/friends/requests',
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'addresseeEmail': email}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('No se pudo enviar la solicitud');
    }
  }

  static String _initials(String name) {
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}