import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'session_store.dart';
import 'package:dio/dio.dart';

import '../analytics/analytics_facade.dart';
import 'http_cache_service.dart';

final authSession = AuthSession();

class AuthService {
  AuthService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl =
            baseUrl ?? (_env('API_BASE_URL') ?? 'http://10.0.2.2:8080/api');

  final http.Client _client;
  final String _baseUrl;
  static Future<void>? _googleInitialization;
  static GoogleSignInAccount? _googleAccount;

  Future<RegistrationResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );

    final body = _decodeBody(response.body);
    _throwForError(response.statusCode, body, 'crear la cuenta');
    final result = _tokensFrom(body);
    await _saveTokens(result);
    return result;
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final body = _decodeBody(response.body);
    _throwForError(response.statusCode, body, 'iniciar sesión');
    final result = _tokensFrom(body);
    await _saveTokens(result);
    return result;
  }

  // Hace auth para el uso de google calendar y manda el token de identidad al back
  Future<AuthResult> loginWithGoogle() async {
    try {
      final account = await googleAccountForCalendar();

      final idToken = account.authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw const AuthException(
          message: 'Google no devolvió un token de identidad.',
        );
      }

      return await exchangeGoogleIdToken(idToken);
    } on GoogleSignInException catch (error) {
      debugPrint('[GOOGLE][LOGIN] ${error.code} - ${error.description}');

      throw AuthException(
        message:
            error.description ?? 'No fue posible iniciar sesión con Google.',
      );
    }
  }

  Future<AuthResult> exchangeGoogleIdToken(String idToken) async {
    if (idToken
        .trim()
        .isEmpty) {
      throw const AuthException(
        message: 'Google no devolvió un token de identidad.',
      );
    }
    final response = await _client.post(
      Uri.parse('$_baseUrl/auth/google'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );
    final body = _decodeBody(response.body);
    _throwForError(response.statusCode, body, 'iniciar sesión con Google');
    final result = _tokensFrom(body);
    await _saveTokens(result);
    return result;
  }

  Future<bool> restoreSession() async {
    final preferences = await SharedPreferences.getInstance();

    final refreshToken = preferences.getString('refresh_token');

    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      await refresh().timeout(const Duration(seconds: 5));
      return true;
    } on AuthException catch (error) {
      if (_isRejectedRefreshToken(error)) {
        await clearSession();
        return false;
      }

      // Error del servidor que no representa
      // necesariamente una sesión inválida.
      return true;
    } on http.ClientException {
      // No hay conexión o no se puede contactar al servidor.
      return true;
    } on TimeoutException {
      // El servidor no respondió a tiempo.
      return true;
    }
  }

  Future<AuthResult> refresh() async {
    final preferences = await SharedPreferences.getInstance();
    final refreshToken = preferences.getString('refresh_token');
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const SessionExpiredException();
    }

    final response = await _client.post(
      Uri.parse('$_baseUrl/auth/refresh'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    final body = _decodeBody(response.body);
    _throwForError(response.statusCode, body, 'renovar la sesión');
    final result = _tokensFrom(body);
    await _saveTokens(result);
    return result;
  }

  Future<void> logout() async {
    final preferences = await SharedPreferences.getInstance();
    final refreshToken = preferences.getString('refresh_token');
    try {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        final response = await _client.post(
          Uri.parse('$_baseUrl/auth/logout'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        );
        _throwForError(
          response.statusCode,
          _decodeBody(response.body),
          'cerrar sesión',
        );
      }
    } finally {
      try {
        await HttpCacheService.instance.clear();
      } catch (error) {
        debugPrint('[HTTP CACHE][CLEAR ERROR] $error');
      }

      await clearSession();

      //Cerramos aca la sesion que se tiene con google si esta activa
      try {
        await initializeGoogleSignIn();
        await GoogleSignIn.instance.signOut();

        _googleAccount = null;

        debugPrint('[GOOGLE][SIGNOUT] Sesion de google del usuario cerrada');
      } catch (error, stackTrace) {
        debugPrint('[GOOGLE][SIGNOUT][ERROR] $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  Future<void> clearSession() async {
    await SessionStore().clear();
    AnalyticsFacade.instance.setUserId(null);
  }

  Future<http.Response> authenticatedCachedGet({
    required String path,
    Map<String, String>? headers,
  }) async {
    final preferences = await SharedPreferences.getInstance();

    var accessToken = preferences.getString('access_token');

    if (accessToken == null || accessToken.isEmpty) {
      throw const SessionExpiredException();
    }

    Future<http.Response> send() async {
      final dio = await HttpCacheService.instance.getDio();

      final uri = Uri.parse('$_baseUrl$path');

      final response = await dio.getUri<String>(
        uri,
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken', ...?headers},
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null,
        ),
      );

      final responseHeaders = <String, String>{};

      response.headers.map.forEach((name, values) {
        responseHeaders[name] = values.join(', ');
      });

      return http.Response(
        response.data ?? '',
        response.statusCode ?? 0,
        headers: responseHeaders,
        request: http.Request('GET', uri),
      );
    }

    var response = await send();

    if (response.statusCode != 401) {
      return response;
    }

    // Si el token expiró, conservamos el mecanismo actual de renovación.
    late final AuthResult refreshed;

    try {
      refreshed = await refresh();
    } on AuthException catch (error) {
      if (_isRejectedRefreshToken(error)) {
        await clearSession();
        authSession.setUnauthenticated();

        throw const SessionExpiredException();
      }

      rethrow;
    }

    accessToken = refreshed.accessToken;

    response = await send();

    if (response.statusCode == 401) {
      await clearSession();
      authSession.setUnauthenticated();
      throw const SessionExpiredException();
    }

    return response;
  }

  Future<http.Response> authenticatedRequest({
    required String method,
    required String path,
    Map<String, String>? headers,
    Object? body,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    var accessToken = preferences.getString('access_token');
    if (accessToken == null || accessToken.isEmpty) {
      throw const SessionExpiredException();
    }

    Future<http.Response> send() {
      return _send(
        method: method,
        path: path,
        accessToken: accessToken!,
        headers: headers,
        body: body,
      );
    }

    var response = await send();
    if (response.statusCode != 401) return response;

    late final AuthResult refreshed;
    try {
      refreshed = await refresh();
    } on AuthException catch (error) {
      if (_isRejectedRefreshToken(error)) {
        await clearSession();
        authSession.setUnauthenticated();

        throw const SessionExpiredException();
      }

      rethrow;
    }
    accessToken = refreshed.accessToken;
    response = await send();
    if (response.statusCode == 401) {
      await clearSession();
      authSession.setUnauthenticated();
      throw const SessionExpiredException();
    }
    return response;
  }

  Future<http.Response> authenticatedMultipart({
    required String path,
    required String field,
    required String filePath,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final accessToken = preferences.getString('access_token');
    if (accessToken == null || accessToken.isEmpty) {
      throw const SessionExpiredException();
    }

    Future<http.Response> send(String token) async {
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl$path'))
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath(field, filePath));
      return http.Response.fromStream(await _client.send(request));
    }

    var response = await send(accessToken);
    if (response.statusCode != 401) return response;

    late final AuthResult refreshed;
    try {
      refreshed = await refresh();
    } on AuthException catch (error) {
      if (_isRejectedRefreshToken(error)) {
        await clearSession();
        authSession.setUnauthenticated();

        throw const SessionExpiredException();
      }

      rethrow;
    }
    response = await send(refreshed.accessToken);
    if (response.statusCode == 401) {
      await clearSession();
      authSession.setUnauthenticated();
      throw const SessionExpiredException();
    }
    return response;
  }

  Future<http.Response> _send({
    required String method,
    required String path,
    required String accessToken,
    Map<String, String>? headers,
    Object? body,
  }) {
    final requestHeaders = <String, String>{
      'Authorization': 'Bearer $accessToken',
      ...?headers,
    };
    final uri = Uri.parse('$_baseUrl$path');
    switch (method.toUpperCase()) {
      case 'GET':
        return _client.get(uri, headers: requestHeaders);
      case 'POST':
        return _client.post(uri, headers: requestHeaders, body: body);
      case 'PATCH':
        return _client.patch(uri, headers: requestHeaders, body: body);
      case 'DELETE':
        return _client.delete(uri, headers: requestHeaders);
      default:
        throw ArgumentError.value(method, 'method', 'Unsupported HTTP method');
    }
  }

  Future<void> _saveTokens(AuthResult result) async {
    final userId = AnalyticsFacade.instance.decodeUserId(result.accessToken);
    await SessionStore().saveSession(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      userId: userId,
    );
  }

  void _throwForError(
    int statusCode,
    Map<String, dynamic> body,
    String action,
  ) {
    if (statusCode >= 200 && statusCode < 300) return;
    throw AuthException(
      message: body['message'] as String? ?? 'No fue posible $action.',
      statusCode: statusCode,
    );
  }

  AuthResult _tokensFrom(Map<String, dynamic> body) {
    final accessToken = body['accessToken'];
    final refreshToken = body['refreshToken'];
    if (accessToken is! String || refreshToken is! String) {
      throw const AuthException(
        message: 'La respuesta del servidor no es válida.',
      );
    }
    return AuthResult(accessToken: accessToken, refreshToken: refreshToken);
  }

  static String? _env(String key) {
    if (!dotenv.isInitialized) return null;
    return dotenv.env[key];
  }

  Map<String, dynamic> _decodeBody(String value) {
    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on FormatException {
      return <String, dynamic>{};
    }
  }

  // Intenta recuperar una sesion existente de lo contrario inicia el proceso de auth

  Future<void> initializeGoogleSignIn() async {
    final pendingInitialization = _googleInitialization;

    if (pendingInitialization != null) {
      await pendingInitialization;
      return;
    }

    final serverClientId = (_env('GOOGLE_SERVER_CLIENT_ID') ?? '').trim();

    if (serverClientId.isEmpty) {
      debugPrint(
        '[GOOGLE][CONFIG] GOOGLE_SERVER_CLIENT_ID está vacío. '
        'Comprueba también si google-services.json contiene '
        'un cliente OAuth web.',
      );
    }

    final initialization = GoogleSignIn.instance.initialize(
      serverClientId: serverClientId.isEmpty ? null : serverClientId,
    );

    _googleInitialization = initialization;

    try {
      await initialization;
      debugPrint('[GOOGLE][INIT] Inicialización completada');
    } catch (_) {
      _googleInitialization = null;
      rethrow;
    }
  }

  Future<GoogleSignInAccount> googleAccountForCalendar() async {
    await initializeGoogleSignIn();

    if (_googleAccount != null) {
      debugPrint('[GOOGLE][ACCOUNT] Usando la cuenta guardada');
      return _googleAccount!;
    }

    final google = GoogleSignIn.instance;
    GoogleSignInAccount? account;

    try {
      debugPrint('[GOOGLE][ACCOUNT] Intentando recuperar sesión existente');
      account = await google.attemptLightweightAuthentication();
    } on GoogleSignInException catch (error) {
      debugPrint(
        '[GOOGLE][ACCOUNT] No se pudo recuperar la sesión: '
        '${error.code} - ${error.description}',
      );
    }

    if (account == null) {
      debugPrint('[GOOGLE][ACCOUNT] Solicitando autenticación interactiva');
      account = await google.authenticate();
    }

    _googleAccount = account;

    debugPrint('[GOOGLE][ACCOUNT] Cuenta disponible: ${account.email}');

    return account;
  }

  Future<String?> getCurrentUserId() async {
    final preferences = await SharedPreferences.getInstance();

    final accessToken = preferences.getString('access_token');

    if (accessToken == null || accessToken.isEmpty) {
      return null;
    }

    return AnalyticsFacade.instance.decodeUserId(accessToken);
  }

  bool _isRejectedRefreshToken(AuthException error) {
    return [400, 401, 403].contains(error.statusCode);
  }
}

class AuthResult {
  const AuthResult({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

typedef RegistrationResult = AuthResult;

class AuthException implements Exception {
  const AuthException({required this.message, this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class SessionExpiredException extends AuthException {
  const SessionExpiredException()
    : super(
        message: 'Tu sesión expiró. Inicia sesión nuevamente.',
        statusCode: 401,
      );
}

class AuthSession extends ChangeNotifier {
  bool? isAuthenticated;

  void setAuthenticated() {
    if (isAuthenticated == true) return;
    isAuthenticated = true;
    notifyListeners();
  }

  void setUnauthenticated() {
    if (isAuthenticated == false) return;
    isAuthenticated = false;
    notifyListeners();
  }
}
