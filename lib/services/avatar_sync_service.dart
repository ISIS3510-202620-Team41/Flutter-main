import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../database/local_database_facade.dart';
import '../models/pending_avatar_upload.dart';
import '../models/profile_models.dart';
import '../repositories/pending_avatar_uploads_repository.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../services/photo_storage_service.dart';
import '../services/profile_service.dart';

class AvatarSyncUpdate {
  const AvatarSyncUpdate({
    required this.userId,
    required this.localPath,
    this.status,
    this.error,
    this.profile,
  });

  final String userId;
  final String localPath;
  final AvatarUploadStatus? status;
  final String? error;
  final UserProfile? profile;
}

class AvatarSyncService {
  AvatarSyncService({
    ConnectivityService? connectivityService,
    AuthService? authService,
    ProfileService? profileService,
    PendingAvatarUploadsRepository? repository,
    PhotoStorageService? photoStorage,
  }) : _connectivityService =
           connectivityService ?? ConnectivityService.instance,
       _authService = authService ?? AuthService(),
       _profileService = profileService ?? ProfileService(),
       _injectedRepository = repository,
       _photoStorage = photoStorage ?? PhotoStorageService();

  static final instance = AvatarSyncService();

  final ConnectivityService _connectivityService;
  final AuthService _authService;
  final ProfileService _profileService;
  final PendingAvatarUploadsRepository? _injectedRepository;
  final PhotoStorageService _photoStorage;

  PendingAvatarUploadsRepository? get _repository =>
      _injectedRepository ?? LocalDatabaseFacade.instance.pendingAvatarUploads;

  final StreamController<AvatarSyncUpdate> _updates =
      StreamController<AvatarSyncUpdate>.broadcast();

  Stream<AvatarSyncUpdate> get updates => _updates.stream;

  StreamSubscription<bool>? _connectivitySubscription;
  final Set<String> _activePaths = {};
  bool _isSyncing = false;
  bool _syncRequested = false;

  void start() {
    if (_connectivitySubscription != null) return;

    authSession.addListener(_onAuthenticationChanged);
    _connectivitySubscription = _connectivityService.onConnectivityChanged
        .listen((online) {
          if (online) _launchSync();
        });

    if (authSession.isAuthenticated == true) _launchSync();
  }

  Future<void> stop() async {
    authSession.removeListener(_onAuthenticationChanged);
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  Future<PendingAvatarUpload?> getUploadForUser(String userId) async {
    return _repository?.getForUser(userId);
  }

  Future<PendingAvatarUpload> enqueuePhoto({
    required String userId,
    required String localPath,
  }) async {
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId');
    }
    if (!await _photoStorage.exists(localPath)) {
      throw FileSystemException('La foto local no existe.', localPath);
    }

    final repository = _requireRepository();
    final previousPath = await _photoStorage.avatarPathForUser(userId);
    final upload = await repository.enqueueLatest(
      userId: userId,
      localPath: localPath,
    );
    await _photoStorage.saveAvatarReference(
      userId: userId,
      localPath: localPath,
    );
    _publish(upload);
    if (previousPath != null && previousPath != localPath) {
      await _deleteIfUnreferenced(userId, previousPath);
    }

    if (_connectivityService.isOnline == true) {
      await syncForUser(userId);
    }
    return upload;
  }

  Future<void> syncCurrentUser() async {
    if (authSession.isAuthenticated != true) return;
    final userId = await _authService.getCurrentUserId();
    if (userId == null || userId.isEmpty) return;
    await syncForUser(userId);
  }

  void requestSyncCurrentUser() => _launchSync();

  Future<void> syncForUser(String userId) async {
    if (authSession.isAuthenticated != true) return;
    final repository = _repository;
    if (repository == null) return;

    final currentUserId = await _authService.getCurrentUserId();
    if (currentUserId != userId) return;

    if (_isSyncing) {
      _syncRequested = true;
      return;
    }

    _isSyncing = true;
    String? blockedUploadId;
    try {
      await repository.recoverProcessing(userId);

      while (_connectivityService.isOnline == true &&
          authSession.isAuthenticated == true) {
        if (await _authService.getCurrentUserId() != userId) break;

        final upload = await repository.getNextPending(userId);
        if (upload == null) break;

        final claimed = await repository.markProcessing(upload);
        if (claimed == 0) continue;

        blockedUploadId = null;
        _activePaths.add(upload.localPath);
        _publish(
          upload.copyWith(
            status: AvatarUploadStatus.processing,
            attemptCount: upload.attemptCount + 1,
            clearLastError: true,
          ),
        );

        var retryLater = false;
        try {
          if (!await _photoStorage.exists(upload.localPath)) {
            const error =
                'La copia local de la foto no existe. Selecciona otra imagen.';
            await repository.markFailed(upload, error: error);
            await _publishIfCurrent(
              repository,
              upload,
              AvatarSyncUpdate(
                userId: upload.userId,
                localPath: upload.localPath,
                status: AvatarUploadStatus.failed,
                error: error,
              ),
            );
            blockedUploadId = upload.id;
            break;
          }

          final profile = await _profileService.uploadAvatar(upload.localPath);
          final remoteUrl = profile.avatarUrl?.trim();
          if (remoteUrl == null || remoteUrl.isEmpty) {
            throw const FormatException(
              'El servidor no devolvió la URL de la foto.',
            );
          }

          final current = await repository.getForUser(userId);
          if (current?.id == upload.id) {
            await _photoStorage.saveAvatarReference(
              userId: userId,
              localPath: upload.localPath,
              remoteUrl: remoteUrl,
            );
            final latest = await repository.getForUser(userId);
            if (latest?.id == upload.id) {
              await repository.deleteIfCurrent(upload);
              _updates.add(
                AvatarSyncUpdate(
                  userId: userId,
                  localPath: upload.localPath,
                  profile: profile,
                ),
              );
            } else if (latest != null) {
              await _photoStorage.saveAvatarReference(
                userId: userId,
                localPath: latest.localPath,
              );
              _publish(latest);
            }
          } else if (current != null) {
            await _photoStorage.saveAvatarReference(
              userId: userId,
              localPath: current.localPath,
            );
            _publish(current);
          }
        } on SessionExpiredException {
          const error = 'Inicia sesión de nuevo para sincronizar la foto.';
          await repository.markPending(upload, error: error);
          await _publishIfCurrent(
            repository,
            upload,
            AvatarSyncUpdate(
              userId: upload.userId,
              localPath: upload.localPath,
              status: AvatarUploadStatus.pending,
              error: error,
            ),
          );
          blockedUploadId = upload.id;
          retryLater = true;
        } on ProfileException catch (error) {
          final retryable = _isRetryableStatus(error.statusCode);
          if (retryable) {
            await repository.markPending(upload, error: error.message);
            await _publishIfCurrent(
              repository,
              upload,
              AvatarSyncUpdate(
                userId: upload.userId,
                localPath: upload.localPath,
                status: AvatarUploadStatus.pending,
                error: error.message,
              ),
            );
            blockedUploadId = upload.id;
            retryLater = true;
          } else {
            await repository.markFailed(upload, error: error.message);
            await _publishIfCurrent(
              repository,
              upload,
              AvatarSyncUpdate(
                userId: upload.userId,
                localPath: upload.localPath,
                status: AvatarUploadStatus.failed,
                error: error.message,
              ),
            );
            blockedUploadId = upload.id;
          }
        } on TimeoutException catch (error) {
          await _markRetryableFailure(repository, upload, error.toString());
          blockedUploadId = upload.id;
          retryLater = true;
        } on SocketException catch (error) {
          await _markRetryableFailure(repository, upload, error.message);
          blockedUploadId = upload.id;
          retryLater = true;
        } on http.ClientException catch (error) {
          await _markRetryableFailure(repository, upload, error.message);
          blockedUploadId = upload.id;
          retryLater = true;
        } on HandshakeException catch (error) {
          await _markRetryableFailure(repository, upload, error.message);
          blockedUploadId = upload.id;
          retryLater = true;
        } on FormatException catch (error) {
          await repository.markFailed(upload, error: error.message);
          await _publishIfCurrent(
            repository,
            upload,
            AvatarSyncUpdate(
              userId: upload.userId,
              localPath: upload.localPath,
              status: AvatarUploadStatus.failed,
              error: error.message,
            ),
          );
          blockedUploadId = upload.id;
        } catch (error, stackTrace) {
          debugPrint('[AVATAR SYNC][ERROR] $error');
          debugPrintStack(stackTrace: stackTrace);
          await repository.markFailed(upload, error: error.toString());
          await _publishIfCurrent(
            repository,
            upload,
            AvatarSyncUpdate(
              userId: upload.userId,
              localPath: upload.localPath,
              status: AvatarUploadStatus.failed,
              error: error.toString(),
            ),
          );
          blockedUploadId = upload.id;
        } finally {
          _activePaths.remove(upload.localPath);
          await _deleteIfUnreferenced(userId, upload.localPath);
        }

        if (retryLater) {
          final latest = await repository.getNextPending(userId);
          if (latest == null || latest.id == blockedUploadId) break;
        } else if (blockedUploadId != null) {
          final latest = await repository.getNextPending(userId);
          if (latest == null || latest.id == blockedUploadId) break;
        }
      }
    } finally {
      _isSyncing = false;
      final retryRequested = _syncRequested;
      _syncRequested = false;
      if (retryRequested && blockedUploadId != null) {
        final latest = await repository.getNextPending(userId);
        if (latest != null && latest.id != blockedUploadId) {
          _launchSync();
        }
      } else if (retryRequested && blockedUploadId == null) {
        _launchSync();
      }
    }
  }

  Future<void> retryFailed(String userId) async {
    final repository = _requireRepository();
    await repository.retryFailed(userId);
    await syncForUser(userId);
  }

  Future<void> _markRetryableFailure(
    PendingAvatarUploadsRepository repository,
    PendingAvatarUpload upload,
    String error,
  ) async {
    await repository.markPending(upload, error: error);
    await _publishIfCurrent(
      repository,
      upload,
      AvatarSyncUpdate(
        userId: upload.userId,
        localPath: upload.localPath,
        status: AvatarUploadStatus.pending,
        error: error,
      ),
    );
  }

  Future<void> _publishIfCurrent(
    PendingAvatarUploadsRepository repository,
    PendingAvatarUpload upload,
    AvatarSyncUpdate update,
  ) async {
    final current = await repository.getForUser(upload.userId);
    if (current?.id == upload.id) _publishUpdate(update);
  }

  bool _isRetryableStatus(int? statusCode) {
    return statusCode == 401 ||
        statusCode == 408 ||
        statusCode == 429 ||
        (statusCode != null && statusCode >= 500);
  }

  Future<void> _deleteIfUnreferenced(String userId, String path) async {
    if (_activePaths.contains(path)) return;

    final currentPath = await _photoStorage.avatarPathForUser(userId);
    if (currentPath == path) return;

    final currentUpload = await _repository?.getForUser(userId);
    if (currentUpload?.localPath == path) return;

    await _photoStorage.delete(path);
  }

  PendingAvatarUploadsRepository _requireRepository() {
    final repository = _repository;
    if (repository == null) {
      throw StateError('La base local no está inicializada.');
    }
    return repository;
  }

  void _publish(PendingAvatarUpload upload) {
    _publishUpdate(
      AvatarSyncUpdate(
        userId: upload.userId,
        localPath: upload.localPath,
        status: upload.status,
        error: upload.lastError,
      ),
    );
  }

  void _publishUpdate(AvatarSyncUpdate update) {
    _updates.add(update);
  }

  void _onAuthenticationChanged() {
    if (authSession.isAuthenticated == true) _launchSync();
  }

  void _launchSync() {
    unawaited(
      syncCurrentUser().catchError((Object error, StackTrace stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'avatar synchronization',
          ),
        );
      }),
    );
  }
}
