import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:llamalla/database/app_database.dart';
import 'package:llamalla/models/pending_avatar_upload.dart';
import 'package:llamalla/models/profile_models.dart';
import 'package:llamalla/repositories/pending_avatar_uploads_repository.dart';
import 'package:llamalla/services/auth_service.dart';
import 'package:llamalla/services/avatar_sync_service.dart';
import 'package:llamalla/services/connectivity_service.dart';
import 'package:llamalla/services/photo_storage_service.dart';
import 'package:llamalla/services/profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeConnectivityService implements ConnectivityService {
  _FakeConnectivityService(this.isOnline);

  @override
  bool? isOnline;

  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> dispose() => _controller.close();
}

class _FakeAuthService extends AuthService {
  @override
  Future<String?> getCurrentUserId() async => 'user-1';
}

class _FakeProfileService extends ProfileService {
  int uploadCount = 0;
  Future<UserProfile> Function(String filePath)? onUpload;

  @override
  Future<UserProfile> uploadAvatar(String filePath) async {
    uploadCount++;
    final callback = onUpload;
    if (callback != null) return callback(filePath);
    return const UserProfile(
      id: 'user-1',
      email: 'user@example.com',
      name: 'User',
      bio: '',
      avatarUrl: 'https://example.com/avatar.jpg',
    );
  }
}

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late PendingAvatarUploadsRepository repository;
  late _FakeConnectivityService connectivity;
  late _FakeProfileService profileService;
  late PhotoStorageService photoStorage;
  late AvatarSyncService syncService;
  late Directory temp;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    authSession.setUnauthenticated();

    database = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    repository = PendingAvatarUploadsRepository(await database.database);
    connectivity = _FakeConnectivityService(false);
    profileService = _FakeProfileService();
    temp = await Directory.systemTemp.createTemp('avatar_sync_test');
    photoStorage = PhotoStorageService(documentsDirectory: () async => temp);
    syncService = AvatarSyncService(
      connectivityService: connectivity,
      authService: _FakeAuthService(),
      profileService: profileService,
      repository: repository,
      photoStorage: photoStorage,
    );
    authSession.setAuthenticated();
  });

  tearDown(() async {
    authSession.setUnauthenticated();
    await connectivity.dispose();
    await database.close();
    await temp.delete(recursive: true);
  });

  test('keeps only the latest local avatar for a user', () async {
    final first = await photoStorage.savePhotoBytes([1]);
    final latest = await photoStorage.savePhotoBytes([2]);

    await syncService.enqueuePhoto(userId: 'user-1', localPath: first.path);
    await syncService.enqueuePhoto(userId: 'user-1', localPath: latest.path);

    final upload = await repository.getForUser('user-1');
    expect(upload?.localPath, latest.path);
    expect(await photoStorage.exists(first.path), isFalse);
    expect(await photoStorage.exists(latest.path), isTrue);
    expect(profileService.uploadCount, 0);
  });

  test('syncs the queued local photo after connectivity returns', () async {
    final photo = await photoStorage.savePhotoBytes([1, 2, 3]);
    await syncService.enqueuePhoto(userId: 'user-1', localPath: photo.path);

    expect(profileService.uploadCount, 0);
    expect((await repository.getForUser('user-1'))?.localPath, photo.path);

    connectivity.isOnline = true;
    await syncService.syncForUser('user-1');

    expect(profileService.uploadCount, 1);
    expect(await repository.getForUser('user-1'), isNull);
    expect(await photoStorage.exists(photo.path), isTrue);
    expect(await photoStorage.avatarPathForUser('user-1'), photo.path);
    expect(
      await photoStorage.avatarUrlForUser('user-1'),
      'https://example.com/avatar.jpg',
    );
  });

  test(
    'does not publish an old upload failure after a newer photo is queued',
    () async {
      final first = await photoStorage.savePhotoBytes([1]);
      final latest = await photoStorage.savePhotoBytes([2]);
      await syncService.enqueuePhoto(userId: 'user-1', localPath: first.path);
      connectivity.isOnline = true;

      final updates = <AvatarSyncUpdate>[];
      final subscription = syncService.updates.listen(updates.add);
      profileService.onUpload = (filePath) async {
        if (filePath == first.path) {
          await syncService.enqueuePhoto(
            userId: 'user-1',
            localPath: latest.path,
          );
          throw const ProfileException('temporary error', statusCode: 503);
        }
        return const UserProfile(
          id: 'user-1',
          email: 'user@example.com',
          name: 'User',
          bio: '',
          avatarUrl: 'https://example.com/avatar.jpg',
        );
      };

      await syncService.syncForUser('user-1');

      expect(await repository.getForUser('user-1'), isNull);
      expect(await photoStorage.avatarPathForUser('user-1'), latest.path);
      expect(
        updates.where(
          (update) =>
              update.localPath == first.path &&
              update.status != AvatarUploadStatus.processing,
        ),
        isEmpty,
      );
      expect(updates.last.localPath, latest.path);
      expect(updates.last.profile?.avatarUrl, 'https://example.com/avatar.jpg');
      await subscription.cancel();
    },
  );
}
