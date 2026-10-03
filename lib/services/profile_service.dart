import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/profile_models.dart';
import 'auth_service.dart';

class ProfileException implements Exception {
  const ProfileException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ProfileService {
  ProfileService({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  Future<UserProfile> getCurrentUser() async {
    final response = await _request('GET', '/users/me');
    return UserProfile.fromJson(_decode(response));
  }

  Future<UserProfile> updateProfile({
    required String name,
    required String bio,
  }) async {
    final response = await _request(
      'PATCH',
      '/users/me',
      body: jsonEncode({'name': name, 'bio': bio}),
    );
    return UserProfile.fromJson(_decode(response));
  }

  Future<UserProfile> uploadAvatar(String filePath) async {
    final response = await _authService.authenticatedMultipart(
      path: '/users/me/avatar',
      field: 'file',
      filePath: filePath,
    );
    return UserProfile.fromJson(_decode(response));
  }

  Future<http.Response> _request(
    String method,
    String path, {
    String? body,
  }) {
    return _authService.authenticatedRequest(
      method: method,
      path: path,
      headers: const {'Content-Type': 'application/json'},
      body: body,
    );
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _error(response, 'cargar el perfil');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const ProfileException('Respuesta inválida del perfil.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  ProfileException _error(http.Response response, String action) {
    var message = 'No fue posible $action.';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] is String) {
        message = decoded['message'] as String;
      }
    } on FormatException {
      // Use the standard message when the backend does not return JSON.
    }
    return ProfileException(message, statusCode: response.statusCode);
  }
}
