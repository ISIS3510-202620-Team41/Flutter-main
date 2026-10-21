import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../models/profile_models.dart';
import 'auth_service.dart';
final currentProfile = ValueNotifier<UserProfile?>(null);

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
    return _withFullAvatar(UserProfile.fromJson(_decode(response)));
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
    return _withFullAvatar(UserProfile.fromJson(_decode(response)));
  }

  Future<UserProfile> uploadAvatar(String filePath) async {
    final response = await _authService.authenticatedMultipart(
      path: '/users/me/avatar',
      field: 'file',
      filePath: filePath,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _error(response, 'subir la foto de perfil');
    }
    final response2 = await _request('GET', '/users/me');
    return _withFullAvatar(
      UserProfile.fromJson(_decode(response2)),
      bustCache: true,
    );
  }

  UserProfile _withFullAvatar(UserProfile profile, {bool bustCache = false}) {
    final fixed = _fixAvatar(profile, bustCache: bustCache);
    currentProfile.value = fixed;
    return fixed;
  }

  UserProfile _fixAvatar(UserProfile profile, {bool bustCache = false}) {
    final raw = profile.avatarUrl;
    if (raw == null || raw.isEmpty) return profile;

    final server = Uri.parse(_authService.baseUrl);
    var uri = Uri.parse(raw);
    if (!uri.hasScheme) {
      uri = server.resolve(raw.startsWith('/') ? raw : '/$raw');
    } else if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
      uri = uri.replace(host: server.host, port: server.port);
    }
    if (bustCache && uri.query.isEmpty) {
      uri = uri.replace(
        queryParameters: {'v': '${DateTime.now().millisecondsSinceEpoch}'},
      );
    }


    return UserProfile(
      id: profile.id,
      email: profile.email,
      name: profile.name,
      bio: profile.bio,
      avatarUrl: uri.toString(),
    );
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
