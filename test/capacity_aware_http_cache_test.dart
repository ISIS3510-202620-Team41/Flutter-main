import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llamalla/models/storage_capacity.dart';
import 'package:llamalla/services/http_cache_service.dart';
import 'package:llamalla/services/storage_capacity_service.dart';
import 'package:llamalla/services/storage_cleanup_service.dart';
import 'package:llamalla/services/storage_write_error.dart';

class _FailingCacheStore extends MemCacheStore {
  _FailingCacheStore([this.failure = const FileSystemException('disk full')]);

  final Object failure;
  bool writeAttempted = false;

  @override
  Future<void> set(CacheResponse response) async {
    writeAttempted = true;
    throw failure;
  }
}

class _SuccessfulResponseAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"ok":true}',
      200,
      headers: const {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        'cache-control': ['public, max-age=60'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'returns an HTTP response when saving its optional cache entry fails',
    () async {
      final innerStore = _FailingCacheStore();
      final reportedErrors = <Object>[];
      final store = CapacityAwareCacheStore(
        innerStore: innerStore,
        cleanupService: StorageCleanupService(
          capacityService: StorageCapacityService(
            readAvailableBytes: () async => 1_000,
            minimumFreeBytes: 0,
            safetyMarginBytes: 0,
          ),
          steps: const [],
        ),
        reportError: (error, _) => reportedErrors.add(error),
      );
      final dio = Dio()..httpClientAdapter = _SuccessfulResponseAdapter();
      dio.interceptors.add(
        DioCacheInterceptor(
          options: CacheOptions(store: store, policy: CachePolicy.request),
        ),
      );

      try {
        final response = await dio.get<Map<String, dynamic>>(
          'https://example.test/activity',
        );

        expect(response.statusCode, 200);
        expect(response.data, {'ok': true});
        expect(innerStore.writeAttempted, isTrue);
        expect(reportedErrors, hasLength(1));
        expect(reportedErrors.single, isA<StorageWriteException>());
        expect(
          (reportedErrors.single as StorageWriteException).kind,
          StorageFailureKind.fileSystem,
        );
      } finally {
        dio.close(force: true);
      }
    },
  );

  test(
    'keeps the HTTP response when an unexpected cache write error occurs',
    () async {
      final innerStore = _FailingCacheStore(StateError('unexpected failure'));
      final reportedErrors = <Object>[];
      final store = CapacityAwareCacheStore(
        innerStore: innerStore,
        cleanupService: StorageCleanupService(
          capacityService: StorageCapacityService(
            readAvailableBytes: () async => 1_000,
            minimumFreeBytes: 0,
            safetyMarginBytes: 0,
          ),
          steps: const [],
        ),
        reportError: (error, _) => reportedErrors.add(error),
      );
      final dio = Dio()..httpClientAdapter = _SuccessfulResponseAdapter();
      dio.interceptors.add(
        DioCacheInterceptor(
          options: CacheOptions(store: store, policy: CachePolicy.request),
        ),
      );

      try {
        final response = await dio.get<Map<String, dynamic>>(
          'https://example.test/activity',
        );

        expect(response.statusCode, 200);
        expect(response.data, {'ok': true});
        expect(innerStore.writeAttempted, isTrue);
        expect(reportedErrors, hasLength(1));
        expect(reportedErrors.single, isA<StorageWriteException>());
        expect(
          (reportedErrors.single as StorageWriteException).kind,
          StorageFailureKind.unexpected,
        );
      } finally {
        dio.close(force: true);
      }
    },
  );

  test(
    'skips cache writes when available capacity is below the reserve',
    () async {
      final innerStore = _FailingCacheStore();
      final reportedErrors = <Object>[];
      final store = CapacityAwareCacheStore(
        innerStore: innerStore,
        cleanupService: StorageCleanupService(
          capacityService: StorageCapacityService(
            readAvailableBytes: () async => 5,
            minimumFreeBytes: 10,
            safetyMarginBytes: 5,
          ),
          steps: const [],
        ),
        reportError: (error, _) => reportedErrors.add(error),
      );
      final dio = Dio()..httpClientAdapter = _SuccessfulResponseAdapter();
      dio.interceptors.add(
        DioCacheInterceptor(
          options: CacheOptions(store: store, policy: CachePolicy.request),
        ),
      );

      try {
        final response = await dio.get<Map<String, dynamic>>(
          'https://example.test/activity',
        );

        expect(response.statusCode, 200);
        expect(innerStore.writeAttempted, isFalse);
        expect(reportedErrors, isEmpty);
      } finally {
        dio.close(force: true);
      }
    },
  );

  test(
    'evicts regenerable cache data before retrying an HTTP cache write',
    () async {
      var availableBytes = 5;
      var cleanupCount = 0;
      final innerStore = _FailingCacheStore();
      final cleanupService = StorageCleanupService(
        capacityService: StorageCapacityService(
          readAvailableBytes: () async => availableBytes,
          minimumFreeBytes: 10,
          safetyMarginBytes: 0,
        ),
        steps: [
          StorageCleanupStep(
            name: 'cached images',
            cleanup: () async {
              cleanupCount++;
              availableBytes = 100;
            },
          ),
        ],
      );
      final reportedErrors = <Object>[];
      final store = CapacityAwareCacheStore(
        innerStore: innerStore,
        cleanupService: cleanupService,
        reportError: (error, _) => reportedErrors.add(error),
      );
      final dio = Dio()..httpClientAdapter = _SuccessfulResponseAdapter();
      dio.interceptors.add(
        DioCacheInterceptor(
          options: CacheOptions(store: store, policy: CachePolicy.request),
        ),
      );

      try {
        final response = await dio.get<Map<String, dynamic>>(
          'https://example.test/activity',
        );

        expect(response.statusCode, 200);
        expect(cleanupCount, 1);
        expect(innerStore.writeAttempted, isTrue);
        expect(reportedErrors, hasLength(1));
      } finally {
        dio.close(force: true);
      }
    },
  );
}
