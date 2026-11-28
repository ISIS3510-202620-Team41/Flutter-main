import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/pending_avatar_upload.dart';
import '../models/profile_models.dart';
import '../services/auth_service.dart';
import '../services/avatar_sync_service.dart';
import '../services/photo_storage_service.dart';
import '../services/profile_service.dart';

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({
    ProfileService? profileService,
    AuthService? authService,
    AvatarSyncService? avatarSyncService,
    PhotoStorageService? photoStorage,
  }) : _profileService = profileService ?? ProfileService(),
       _authService = authService ?? AuthService(),
       _avatarSyncService = avatarSyncService ?? AvatarSyncService.instance,
       _photoStorage = photoStorage ?? PhotoStorageService() {
    _avatarUpdates = _avatarSyncService.updates.listen(_onAvatarSyncUpdate);
  }

  final ProfileService _profileService;
  final AuthService _authService;
  final AvatarSyncService _avatarSyncService;
  final PhotoStorageService _photoStorage;
  late final StreamSubscription<AvatarSyncUpdate> _avatarUpdates;

  UserProfile? profile;
  bool isLoading = false;
  bool isSaving = false;
  bool isUploadingAvatar = false;
  bool isExportingAvatar = false;
  String? errorMessage;
  String? localAvatarPath;
  String? localAvatarUrl;
  String? avatarUploadError;
  AvatarUploadStatus? avatarUploadStatus;
  String? _currentUserId;

  bool get shouldShowLocalAvatar {
    final path = localAvatarPath;
    if (path == null) return false;
    if (avatarUploadStatus != null) return true;
    if (profile == null) return true;
    return profile!.avatarUrl != null && profile!.avatarUrl == localAvatarUrl;
  }

  Future<UserProfile?> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final userId = await _authService.getCurrentUserId();
      if (_currentUserId != userId) {
        profile = null;
        localAvatarPath = null;
        localAvatarUrl = null;
        avatarUploadStatus = null;
        avatarUploadError = null;
      }
      _currentUserId = userId;
      if (userId != null) {
        await _loadLocalAvatar(userId);
      }

      profile = await _profileService.getCurrentUser();
      if (userId != null) {
        await _discardStaleAvatarCopy(userId);
      }
      return profile;
    } on ProfileException catch (error) {
      errorMessage = error.message;
    } on FormatException catch (error) {
      errorMessage = error.message;
    } catch (error, stackTrace) {
      debugPrint('[PROFILE][LOAD ERROR] $error');
      debugPrintStack(stackTrace: stackTrace);
      errorMessage = 'No pudimos conectar con el servidor. Revisa tu conexión.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
    return null;
  }

  Future<UserProfile?> updateProfile({
    required String name,
    required String bio,
  }) async {
    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      profile = await _profileService.updateProfile(name: name, bio: bio);
      return profile;
    } on ProfileException catch (error) {
      errorMessage = error.message;
    } on FormatException catch (error) {
      errorMessage = error.message;
    } catch (_) {
      errorMessage = 'No pudimos conectar con el servidor. Revisa tu conexión.';
    } finally {
      isSaving = false;
      notifyListeners();
    }
    return null;
  }

  Future<UserProfile?> uploadAvatar(String filePath) async {
    isUploadingAvatar = true;
    errorMessage = null;
    notifyListeners();
    try {
      profile = await _profileService.uploadAvatar(filePath);
      return profile;
    } on ProfileException catch (error) {
      errorMessage = error.message;
    } on FormatException catch (error) {
      errorMessage = error.message;
    } catch (_) {
      errorMessage = 'No pudimos conectar con el servidor. Revisa tu conexión.';
    } finally {
      isUploadingAvatar = false;
      notifyListeners();
    }
    return null;
  }

  Future<void> queueAvatarUpload(String localPath) async {
    final userId = _currentUserId ?? await _authService.getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      throw const ProfileException(
        'No pudimos identificar tu sesión para guardar la foto.',
      );
    }

    _currentUserId = userId;
    localAvatarPath = localPath;
    localAvatarUrl = null;
    avatarUploadStatus = AvatarUploadStatus.pending;
    avatarUploadError = null;
    notifyListeners();

    try {
      await _avatarSyncService.enqueuePhoto(
        userId: userId,
        localPath: localPath,
      );
      final current = await _avatarSyncService.getUploadForUser(userId);
      if (current == null) {
        avatarUploadStatus = null;
        avatarUploadError = null;
      } else {
        _setAvatarUpload(current);
      }
    } catch (error) {
      avatarUploadError = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> retryAvatarUpload() async {
    final userId = _currentUserId;
    if (userId == null) return;
    await _avatarSyncService.retryFailed(userId);
  }

  Future<void> exportAvatarToGallery() async {
    if (isExportingAvatar) return;

    isExportingAvatar = true;
    errorMessage = null;
    notifyListeners();
    try {
      Uint8List bytes;
      final path = localAvatarPath;
      if (path != null && await _photoStorage.exists(path)) {
        bytes = await _photoStorage.readPhotoBytes(path);
      } else {
        final url = profile?.avatarUrl ?? localAvatarUrl;
        if (url == null || url.isEmpty) {
          throw const ProfileException('No hay una foto para exportar.');
        }
        bytes = await _profileService.downloadAvatarBytes(url);
      }
      await _photoStorage.exportToGallery(
        bytes: bytes,
        fileName: 'llamalla_avatar_${_currentUserId ?? 'profile'}.jpg',
      );
    } on ProfileException catch (error) {
      errorMessage = error.message;
      rethrow;
    } on PhotoStorageException catch (error) {
      errorMessage = error.message;
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('[PROFILE][AVATAR EXPORT ERROR] $error');
      debugPrintStack(stackTrace: stackTrace);
      errorMessage = 'No pudimos guardar la foto en el dispositivo.';
      rethrow;
    } finally {
      isExportingAvatar = false;
      notifyListeners();
    }
  }

  Future<void> _loadLocalAvatar(String userId) async {
    final pending = await _avatarSyncService.getUploadForUser(userId);
    final savedPath = await _photoStorage.avatarPathForUser(userId);
    final path = pending?.localPath ?? savedPath;
    final exists = path != null && await _photoStorage.exists(path);

    if (exists) {
      localAvatarPath = path;
      localAvatarUrl = pending == null
          ? await _photoStorage.avatarUrlForUser(userId)
          : null;
    } else {
      localAvatarPath = null;
      localAvatarUrl = null;
    }
    if (pending != null) {
      _setAvatarUpload(pending);
    } else {
      avatarUploadStatus = null;
      avatarUploadError = null;
    }
    notifyListeners();
  }

  Future<void> _discardStaleAvatarCopy(String userId) async {
    final pending = await _avatarSyncService.getUploadForUser(userId);
    final path = localAvatarPath;
    if (pending != null ||
        path == null ||
        profile?.avatarUrl == localAvatarUrl) {
      return;
    }

    await _photoStorage.clearAvatarReference(userId);
    await _photoStorage.delete(path);
    localAvatarPath = null;
    localAvatarUrl = null;
  }

  void _onAvatarSyncUpdate(AvatarSyncUpdate update) {
    if (update.userId != _currentUserId) return;

    localAvatarPath = update.localPath;
    localAvatarUrl = update.profile?.avatarUrl ?? localAvatarUrl;
    avatarUploadStatus = update.status;
    avatarUploadError = update.error;
    if (update.profile != null) profile = update.profile;
    notifyListeners();
  }

  void _setAvatarUpload(PendingAvatarUpload upload) {
    localAvatarPath = upload.localPath;
    avatarUploadStatus = upload.status;
    avatarUploadError = upload.lastError;
  }

  @override
  void dispose() {
    unawaited(_avatarUpdates.cancel());
    super.dispose();
  }
}
