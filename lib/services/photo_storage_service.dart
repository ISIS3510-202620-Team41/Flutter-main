import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'storage_write_error.dart';

typedef GalleryImageSaver =
    Future<bool> Function(Uint8List bytes, String fileName);

class PhotoStorageService {
  PhotoStorageService({
    Future<Directory> Function()? documentsDirectory,
    Uuid? uuid,
    GalleryImageSaver? galleryImageSaver,
  }) : _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       _uuid = uuid ?? const Uuid(),
       _galleryImageSaver = galleryImageSaver ?? _saveToGallery;

  static const _folderName = 'photos';
  static const _avatarPathPrefix = 'local_avatar_path_';
  static const _avatarUrlPrefix = 'local_avatar_url_';

  final Future<Directory> Function() _documentsDirectory;
  final Uuid _uuid;
  final GalleryImageSaver _galleryImageSaver;

  Future<File> savePhoto(String sourcePath) async {
    return runStorageWrite('profile photo save', () async {
      final root = await _documentsDirectory();
      final folder = Directory(p.join(root.path, _folderName));
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }

      final extension = p.extension(sourcePath).toLowerCase();
      final fileName = '${_uuid.v4()}${extension.isEmpty ? '.jpg' : extension}';
      return File(sourcePath).copy(p.join(folder.path, fileName));
    });
  }

  Future<File> savePhotoBytes(List<int> bytes) async {
    return runStorageWrite('profile photo save', () async {
      final root = await _documentsDirectory();
      final folder = Directory(p.join(root.path, _folderName));
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }
      final file = File(p.join(folder.path, '${_uuid.v4()}.jpg'));
      return file.writeAsBytes(bytes, flush: true);
    });
  }

  Future<String?> avatarPathForUser(String userId) async {
    _requireUserId(userId);
    return (await SharedPreferences.getInstance()).getString(
      '$_avatarPathPrefix$userId',
    );
  }

  Future<String?> avatarUrlForUser(String userId) async {
    _requireUserId(userId);
    return (await SharedPreferences.getInstance()).getString(
      '$_avatarUrlPrefix$userId',
    );
  }

  Future<void> saveAvatarReference({
    required String userId,
    required String localPath,
    String? remoteUrl,
  }) async {
    _requireUserId(userId);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('$_avatarPathPrefix$userId', localPath);
    if (remoteUrl == null || remoteUrl.isEmpty) {
      await preferences.remove('$_avatarUrlPrefix$userId');
    } else {
      await preferences.setString('$_avatarUrlPrefix$userId', remoteUrl);
    }
  }

  Future<void> clearAvatarReference(String userId) async {
    _requireUserId(userId);
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('$_avatarPathPrefix$userId');
    await preferences.remove('$_avatarUrlPrefix$userId');
  }

  Future<bool> exists(String path) => File(path).exists();

  Future<Uint8List> readPhotoBytes(String path) async {
    return File(path).readAsBytes();
  }

  Future<void> delete(String path) async {
    await runStorageWrite('profile photo removal', () async {
      final file = File(path);
      if (await file.exists()) await file.delete();
    });
  }

  Future<void> exportToGallery({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (bytes.isEmpty) {
      throw const PhotoStorageException('La foto está vacía.');
    }
    final saved = await _galleryImageSaver(bytes, fileName);
    if (!saved) {
      throw const PhotoStorageException(
        'No se pudo guardar la foto en la galería.',
      );
    }
  }

  static Future<bool> _saveToGallery(
    Uint8List bytes,
    String fileName,
  ) async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt < 29 &&
          !await Permission.storage.request().isGranted) {
        throw const PhotoStorageException(
          'Se necesita permiso de almacenamiento para guardar la foto.',
        );
      }
    } else if (Platform.isIOS) {
      final permission = await Permission.photosAddOnly.request();
      if (!permission.isGranted && !permission.isLimited) {
        throw const PhotoStorageException(
          'Se necesita permiso para guardar la foto en Fotos.',
        );
      }
    } else {
      throw const PhotoStorageException(
        'La exportación a galería no está disponible en esta plataforma.',
      );
    }

    final result = await SaverGallery.saveImage(
      bytes,
      fileName: fileName,
      extension: 'jpg',
      skipIfExists: false,
    );
    if (!result.isSuccess) {
      throw PhotoStorageException(
        result.errorMessage ?? 'No se pudo guardar la foto en la galería.',
      );
    }
    return true;
  }

  void _requireUserId(String userId) {
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId');
    }
  }
}

class PhotoStorageException implements Exception {
  const PhotoStorageException(this.message);

  final String message;

  @override
  String toString() => message;
}
