import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:llamalla/services/photo_storage_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory temp;
  late PhotoStorageService service;
  late File source;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temp = await Directory.systemTemp.createTemp('photo_test');
    service = PhotoStorageService(documentsDirectory: () async => temp);
    source = File(p.join(temp.path, 'camera.jpg'))..writeAsBytesSync([1, 2, 3]);
  });

  tearDown(() => temp.delete(recursive: true));

  test(
    'saves the photo with a UUID name in the private photos folder',
    () async {
      final saved = await service.savePhoto(source.path);

      expect(await saved.exists(), isTrue);
      expect(p.basename(p.dirname(saved.path)), 'photos');
      expect(p.basename(saved.path), matches(RegExp(r'^[0-9a-f-]{36}\.jpg$')));
      expect(saved.readAsBytesSync(), [1, 2, 3]);
    },
  );

  test('two photos never share a name', () async {
    final first = await service.savePhoto(source.path);
    final second = await service.savePhoto(source.path);

    expect(first.path, isNot(second.path));
  });

  test('delete removes the file', () async {
    final saved = await service.savePhoto(source.path);
    await service.delete(saved.path);

    expect(await service.exists(saved.path), isFalse);
  });

  test('avatar references are isolated by user', () async {
    await service.saveAvatarReference(
      userId: 'user-a',
      localPath: '/photos/a.jpg',
      remoteUrl: 'https://example.com/a.jpg',
    );
    await service.saveAvatarReference(
      userId: 'user-b',
      localPath: '/photos/b.jpg',
    );

    expect(await service.avatarPathForUser('user-a'), '/photos/a.jpg');
    expect(
      await service.avatarUrlForUser('user-a'),
      'https://example.com/a.jpg',
    );
    expect(await service.avatarPathForUser('user-b'), '/photos/b.jpg');
    expect(await service.avatarUrlForUser('user-b'), isNull);
  });

  test('exports image bytes through the injected gallery saver', () async {
    Uint8List? exportedBytes;
    String? exportedName;
    final galleryService = PhotoStorageService(
      documentsDirectory: () async => temp,
      galleryImageSaver: (bytes, fileName) async {
        exportedBytes = bytes;
        exportedName = fileName;
        return true;
      },
    );

    await galleryService.exportToGallery(
      bytes: Uint8List.fromList([1, 2, 3]),
      fileName: 'avatar.jpg',
    );

    expect(exportedBytes, [1, 2, 3]);
    expect(exportedName, 'avatar.jpg');
  });
}
