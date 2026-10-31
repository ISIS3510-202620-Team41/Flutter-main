
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ActivityImageCacheService {
  Future<String?> downloadAndCache({
    required String activityId,
    required String imageUrl,
  }) async {
    if (imageUrl.isEmpty) return null;

    try {
      final uri = Uri.tryParse(imageUrl);

      if (uri == null ||
          !uri.hasScheme ||
          (uri.scheme != 'http' && uri.scheme != 'https')) {
        return null;
      }

      final directory = await getApplicationSupportDirectory();

      final imageDirectory = Directory(
        p.join(directory.path, 'activity_images'),
      );

      await imageDirectory.create(recursive: true);

      final response = await http.get(uri).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }

      final extension = p.extension(uri.path).isNotEmpty
          ? p.extension(uri.path)
          : '.jpg';

      final safeId = activityId.replaceAll(
        RegExp(r'[^a-zA-Z0-9_-]'),
        '_',
      );

      final file = File(
        p.join(imageDirectory.path, '$safeId$extension'),
      );

      await file.writeAsBytes(response.bodyBytes, flush: true);

      return file.path;
    } catch (e) {
      return null;
    }
  }

  Future<bool> exists(String? path) async {
    if (path == null || path.isEmpty) return false;

    return File(path).exists();
  }
}
