import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:http_cache_file_store/http_cache_file_store.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show getDatabasesPath;

class HttpCacheService {
  HttpCacheService._();

  static final instance = HttpCacheService._();

  Future<Dio>? _dioFuture;
  FileCacheStore? _store;

  Future<Dio> getDio() {
    return _dioFuture ??= _createDio();
  }

  Future<Dio> _createDio() async {
    final databasePath = await getDatabasesPath();

    final cacheDirectory = Directory(
      p.join(databasePath, 'http_cache'),
    );

    await cacheDirectory.create(recursive: true);

    final store = FileCacheStore(cacheDirectory.path);
    _store = store;

    // Politicas
    final cacheOptions = CacheOptions(
      store: store,
      policy: CachePolicy.request,
      hitCacheOnNetworkFailure: true,
      keyBuilder: _cacheKey,
    );

    final dio = Dio();

    dio.interceptors.add(
      DioCacheInterceptor(options: cacheOptions),
    );

    return dio;
  }

  String _cacheKey({
    Object? body,
    Map<String, String>? headers,
    required Uri url,
  }) {
    String? authorization;

    if (headers != null) {
      for (final entry in headers.entries) {
        if (entry.key.toLowerCase() == 'authorization') {
          authorization = entry.value;
          break;
        }
      }
    }

    final userScope = _userScope(authorization);

    final requestKey = CacheOptions.defaultCacheKeyBuilder(
      body: body,
      headers: null,
      url: url,
    );

    return '$userScope::$requestKey';
  }

  //Usado para evitar que las respuestas personalizadas se pasen a otro usuario
  String _userScope(String? authorization) {
    if (authorization == null || authorization.isEmpty) {
      return 'anonymous';
    }

    final token = authorization.replaceFirst(
      RegExp(r'^Bearer\s+', caseSensitive: false),
      '',
    ).trim();

    final parts = token.split('.');

    if (parts.length == 3) {
      try {
        final normalized = base64Url.normalize(parts[1]);

        final payload = jsonDecode(
          utf8.decode(base64Url.decode(normalized)),
        );

        if (payload is Map) {
          final userId =
              payload['sub'] ??
              payload['userId'] ??
              payload['id'];

          if (userId is String && userId.isNotEmpty) {
            return 'user:$userId';
          }
        }
      } catch (_) {
        // Si no es posible leer el JWT, se utiliza el token como scope.
      }
    }

    return 'token:${base64Url.encode(utf8.encode(token))}';
  }

  Future<void> clear() async {
    final pending = _dioFuture;

    if (pending == null) return;

    await pending;
    await _store?.clean();
  }
}