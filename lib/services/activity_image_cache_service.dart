import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../cache/activity_image_cache.dart';
import 'storage_capacity_service.dart';
import 'storage_cleanup_service.dart';

typedef ImageResponseLoader = Future<http.Response> Function(Uri uri);
typedef ImageDirectoryProvider = Future<Directory> Function();
typedef ImageCacheErrorReporter =
    void Function(Object error, StackTrace stackTrace);

class ActivityImageCacheService {
  ActivityImageCacheService({
    StorageCapacityService? capacityService,
    StorageCleanupService? cleanupService,
    ImageResponseLoader? loadImage,
    ImageDirectoryProvider? getSupportDirectory,
    ImageCacheErrorReporter? reportError,
  }) : _capacityService = capacityService ?? StorageCapacityService(),
       _loadImage = loadImage ?? _loadRemoteImage,
       _getSupportDirectory =
           getSupportDirectory ?? getApplicationSupportDirectory,
       _reportError = reportError ?? _reportCacheError {
    _cleanupService =
        cleanupService ??
        StorageCleanupService(
          capacityService: _capacityService,
          steps: [
            StorageCleanupStep(
              name: 'managed activity images',
              cleanup: () => ActivityImageCacheManager.instance.emptyCache(),
            ),
            StorageCleanupStep(
              name: 'local activity images',
              cleanup: clearCache,
            ),
          ],
        );
  }

  final StorageCapacityService _capacityService;
  final ImageResponseLoader _loadImage;
  final ImageDirectoryProvider _getSupportDirectory;
  final ImageCacheErrorReporter _reportError;
  late final StorageCleanupService _cleanupService;

  Future<String?> downloadAndCache({
    required String activityId,
    required String imageUrl,
  }) async {
    final uri = Uri.tryParse(imageUrl);

    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }

    Directory? temporaryDirectory;
    try {
      final response = await _loadImage(uri);

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }

      final contentType = response.headers['content-type'] ?? '';

      if (!contentType.startsWith('image/')) {
        return null;
      }

      final capacity = await _cleanupService.makeRoomForOptionalWrite(
        estimatedWriteBytes: response.bodyBytes.length,
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
        return null;
      }

      final directory = await _getSupportDirectory();
      final imageDirectory = Directory(
        p.join(directory.path, 'activity_images'),
      );
      await imageDirectory.create(recursive: true);

      final safeId = activityId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

      final extension = contentType.contains('png')
          ? '.png'
          : contentType.contains('webp')
          ? '.webp'
          : contentType.contains('gif')
          ? '.gif'
          : '.jpg';

      final downloadDirectory = await imageDirectory.createTemp('.image-');
      temporaryDirectory = downloadDirectory;
      final temporaryFile = File(p.join(downloadDirectory.path, 'download'));
      await temporaryFile.writeAsBytes(response.bodyBytes, flush: true);

      if (await temporaryFile.length() != response.bodyBytes.length) {
        throw FileSystemException(
          'Cached image size did not match the downloaded image.',
          temporaryFile.path,
        );
      }

      final file = File(p.join(imageDirectory.path, '$safeId$extension'));

      if (await file.exists()) {
        await file.delete();
      }

      await temporaryFile.rename(file.path);
      temporaryDirectory = null;
      try {
        await downloadDirectory.delete();
      } on FileSystemException catch (error, stackTrace) {
        _reportError(error, stackTrace);
      }
      return file.path;
    } on SocketException catch (error, stackTrace) {
      _reportError(error, stackTrace);
      await _cleanupTemporaryDirectory(temporaryDirectory);
      return null;
    } on TimeoutException catch (error, stackTrace) {
      _reportError(error, stackTrace);
      await _cleanupTemporaryDirectory(temporaryDirectory);
      return null;
    } on http.ClientException catch (error, stackTrace) {
      _reportError(error, stackTrace);
      await _cleanupTemporaryDirectory(temporaryDirectory);
      return null;
    } on PlatformException catch (error, stackTrace) {
      _reportError(error, stackTrace);
      await _cleanupTemporaryDirectory(temporaryDirectory);
      return null;
    } on MissingPluginException catch (error, stackTrace) {
      _reportError(error, stackTrace);
      await _cleanupTemporaryDirectory(temporaryDirectory);
      return null;
    } on FileSystemException catch (error, stackTrace) {
      _reportError(error, stackTrace);
      await _cleanupTemporaryDirectory(temporaryDirectory);
      return null;
    }
  }

  Future<bool> exists(String? path) async {
    if (path == null || path.isEmpty) return false;

    try {
      final file = File(path);
      return await file.exists() && await file.length() > 0;
    } on FileSystemException catch (error, stackTrace) {
      _reportError(error, stackTrace);
      return false;
    }
  }

  Future<void> clearCache() async {
    final supportDirectory = await _getSupportDirectory();
    final imageDirectory = Directory(
      p.join(supportDirectory.path, 'activity_images'),
    );

    if (await imageDirectory.exists()) {
      await imageDirectory.delete(recursive: true);
    }
  }

  Future<void> _cleanupTemporaryDirectory(Directory? directory) async {
    if (directory == null) return;

    try {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } on FileSystemException catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
  }

  static Future<http.Response> _loadRemoteImage(Uri uri) {
    return http.get(uri).timeout(const Duration(seconds: 20));
  }

  static void _reportCacheError(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'activity image cache',
      ),
    );
  }
}
