
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ActivityImageCacheService {

  Future<String?> downloadAndCache({
    required String activityId,
    required String imageUrl,
  }) async {
    try {
      final uri = Uri.tryParse(imageUrl);

      if (uri == null ||
          (uri.scheme != 'http' && uri.scheme != 'https')) {
        return null;
      }

      final directory = await getApplicationSupportDirectory();

      final imageDirectory = Directory(
        p.join(directory.path, 'activity_images'),
      );

      await imageDirectory.create(recursive: true);

      final response = await http.get(uri).timeout(
        const Duration(seconds: 20),
      );

      if (response.statusCode != 200 ||
          response.bodyBytes.isEmpty) {
        return null;
      }

      final contentType = response.headers['content-type'] ?? '';

      if (!contentType.startsWith('image/')) {
        return null;
      }

      final safeId = activityId.replaceAll(
        RegExp(r'[^a-zA-Z0-9_-]'),
        '_',
      );

      final extension = contentType.contains('png')
          ? '.png'
          : contentType.contains('webp')
              ? '.webp'
              : contentType.contains('gif')
                  ? '.gif'
                  : '.jpg';

      final file = File(
        p.join(imageDirectory.path, '$safeId$extension'),
      );

      await file.writeAsBytes(
        response.bodyBytes,
        flush: true,
      );

      final exists = await file.exists();
      final length = exists ? await file.length() : 0;

      if (!exists || length == 0) {
        return null;
      }

      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<bool> exists(String? path) async {
    if (path == null || path.isEmpty) return false;

    try {
      final file = File(path);
      return await file.exists() && await file.length() > 0;
    } catch (_) {
      return false;
    }
  }
}
