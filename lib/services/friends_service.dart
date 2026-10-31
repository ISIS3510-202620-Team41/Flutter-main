import 'auth_service.dart';

class FriendsService {
  FriendsService({AuthService? authService})
      : _authService = authService ?? AuthService();

  final AuthService _authService;

  /// Llama a /friends/gaps,  el backend emite friend_availability_used (viewed).
  Future<void> loadAvailableFriends() async {
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
  }
}