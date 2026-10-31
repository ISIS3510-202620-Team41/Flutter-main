import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:llamalla/services/photo_storage_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;
  late PhotoStorageService service;
  late File source;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('photo_test');
    service = PhotoStorageService(documentsDirectory: () async => temp);
    source = File(p.join(temp.path, 'camera.jpg'))..writeAsBytesSync([1, 2, 3]);
  });

  tearDown(() => temp.delete(recursive: true));

  test('saves the photo with a UUID name in the private photos folder', () async {
    final saved = await service.savePhoto(source.path);

    expect(await saved.exists(), isTrue);
    expect(p.basename(p.dirname(saved.path)), 'photos');
    expect(
      p.basename(saved.path),
      matches(RegExp(r'^[0-9a-f-]{36}\.jpg$')),
    );
    expect(saved.readAsBytesSync(), [1, 2, 3]);
  });

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
}