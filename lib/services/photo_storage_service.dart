import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

//Almacena las fotos de la cámara en el directorio de documentos PRIVADO de la aplicación
//image_picker deja la foto en una carpeta de caché

class PhotoStorageService {
  PhotoStorageService({
    Future<Directory> Function()? documentsDirectory,
    Uuid? uuid,
  })  : _documentsDirectory =
      documentsDirectory ?? getApplicationDocumentsDirectory,
        _uuid = uuid ?? const Uuid();

  static const _folderName = 'photos';

  final Future<Directory> Function() _documentsDirectory;
  final Uuid _uuid;

  // Copia [sourcePath] en <documents>/photos/<uuid>.<ext> y lo devuelve.
  // El uso de un UUID evita colisiones y no revela el nombre original del archivo.
  Future<File> savePhoto(String sourcePath) async {
    final root = await _documentsDirectory();
    final folder = Directory(p.join(root.path, _folderName));
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final extension = p.extension(sourcePath).toLowerCase();
    final fileName = '${_uuid.v4()}${extension.isEmpty ? '.jpg' : extension}';
    return File(sourcePath).copy(p.join(folder.path, fileName));
  }

  Future<bool> exists(String path) => File(path).exists();

  Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}