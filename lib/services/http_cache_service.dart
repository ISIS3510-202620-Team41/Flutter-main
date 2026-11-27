import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http_cache_file_store/http_cache_file_store.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show DatabaseException, getDatabasesPath;

import '../cache/activity_image_cache.dart';
import 'activity_image_cache_service.dart';
import 'storage_capacity_service.dart';
import 'storage_cleanup_service.dart';
import 'storage_write_error.dart';

typedef CacheStoreErrorReporter =
    void Function(Object error, StackTrace stackTrace);

class CapacityAwareCacheStore extends CacheStore {
  CapacityAwareCacheStore({
    required this.innerStore,
    required this.cleanupService,
    CacheStoreErrorReporter? reportError,
  }) : _reportError = reportError ?? _reportCacheError;

  final CacheStore innerStore;
  final StorageCleanupService cleanupService;
  final CacheStoreErrorReporter _reportError;

  @override
  Future<bool> exists(String key) async {
    try {
      return await innerStore.exists(key);
    } on FileSystemException catch (error, stackTrace) {
      _reportError(error, stackTrace);
      return false;
    }
  }

  @override
  Future<CacheResponse?> get(String key) async {
    try {
      return await innerStore.get(key);
    } on FileSystemException catch (error, stackTrace) {
      _reportError(error, stackTrace);
      return null;
    }
  }

  @override
  Future<List<CacheResponse>> getFromPath(
    RegExp pathPattern, {
    Map<String, String?>? queryParams,
  }) async {
    try {
      return await innerStore.getFromPath(
        pathPattern,
        queryParams: queryParams,
      );
    } on FileSystemException catch (error, stackTrace) {
      _reportError(error, stackTrace);
      return const [];
    }
  }

  @override
  Future<void> set(CacheResponse response) async {
    final capacity = await cleanupService.makeRoomForOptionalWrite(
      estimatedWriteBytes: response.content?.length ?? 0,
    );
    if (!capacity.canWriteOptionalData) {
      if (!capacity.hasCapacityInformation) {
        _reportError(
          StateError(
            capacity.errorMessage ?? 'Unable to check storage capacity.',
          ),
          StackTrace.current,
        );
      }
      return;
    }

    try {
      await innerStore.set(response);
    } catch (error, stackTrace) {
      _reportError(
        StorageWriteException(
          kind: classifyStorageFailure(error),
          operation: 'HTTP cache write',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  @override
  Future<void> delete(String key, {bool staleOnly = false}) async {
    try {
      await innerStore.delete(key, staleOnly: staleOnly);
    } on FileSystemException catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
  }

  @override
  Future<void> deleteFromPath(
    RegExp pathPattern, {
    Map<String, String?>? queryParams,
  }) async {
    try {
      await innerStore.deleteFromPath(pathPattern, queryParams: queryParams);
    } on FileSystemException catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
  }

  @override
  Future<void> clean({
    CachePriority priorityOrBelow = CachePriority.high,
    bool staleOnly = false,
  }) async {
    try {
      await innerStore.clean(
        priorityOrBelow: priorityOrBelow,
        staleOnly: staleOnly,
      );
    } on FileSystemException catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
  }

  @override
  Future<void> close() async {
    try {
      await innerStore.close();
    } on FileSystemException catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
  }

  static void _reportCacheError(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'HTTP response cache',
      ),
    );
  }
}

class HttpCacheService {
  HttpCacheService._();

  static final instance = HttpCacheService._();

  Future<Dio>? _dioFuture;
  CapacityAwareCacheStore? _store;

  Future<Dio> getDio() {
    return _dioFuture ??= _createDio();
  }

  Future<Dio> _createDio() async {
    final dio = Dio();

    try {
      final databasePath = await getDatabasesPath();

      final cacheDirectory = Directory(p.join(databasePath, 'http_cache'));

      await cacheDirectory.create(recursive: true);

      final innerStore = FileCacheStore(cacheDirectory.path);
      final capacityService = StorageCapacityService();
      final imageCacheService = ActivityImageCacheService(
        capacityService: capacityService,
      );
      final cleanupService = StorageCleanupService(
        capacityService: capacityService,
        steps: [
          StorageCleanupStep(
            name: 'stale HTTP responses',
            cleanup: () => innerStore.clean(staleOnly: true),
          ),
          StorageCleanupStep(
            name: 'managed activity images',
            cleanup: () => ActivityImageCacheManager.instance.emptyCache(),
          ),
          StorageCleanupStep(
            name: 'local activity images',
            cleanup: imageCacheService.clearCache,
          ),
          StorageCleanupStep(
            name: 'all HTTP responses',
            cleanup: innerStore.clean,
          ),
        ],
      );
      final capacity = await cleanupService.makeRoomForOptionalWrite();
      if (!capacity.canWriteOptionalData) {
        if (!capacity.hasCapacityInformation) {
          _reportCacheError(
            StateError(
              capacity.errorMessage ?? 'Unable to check storage capacity.',
            ),
            StackTrace.current,
          );
        }
        return dio;
      }

      final store = CapacityAwareCacheStore(
        innerStore: innerStore,
        cleanupService: cleanupService,
      );
      _store = store;

      final cacheOptions = CacheOptions(
        store: store,
        policy: CachePolicy.request,
        hitCacheOnNetworkFailure: true,
        keyBuilder: _cacheKey,
      );

      dio.interceptors.add(DioCacheInterceptor(options: cacheOptions));
    } on FileSystemException catch (error, stackTrace) {
      _reportCacheError(error, stackTrace);
    } on DatabaseException catch (error, stackTrace) {
      _reportCacheError(error, stackTrace);
    } on PlatformException catch (error, stackTrace) {
      _reportCacheError(error, stackTrace);
    } on MissingPluginException catch (error, stackTrace) {
      _reportCacheError(error, stackTrace);
    }

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

    final token = authorization
        .replaceFirst(RegExp(r'^Bearer\s+', caseSensitive: false), '')
        .trim();

    final parts = token.split('.');

    if (parts.length == 3) {
      try {
        final normalized = base64Url.normalize(parts[1]);

        final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));

        if (payload is Map) {
          final userId = payload['sub'] ?? payload['userId'] ?? payload['id'];

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

  static void _reportCacheError(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'HTTP response cache',
      ),
    );
  }
}
