import 'package:flutter/foundation.dart';

import '../models/profile_models.dart';
import '../services/profile_service.dart';

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({ProfileService? profileService})
      : _profileService = profileService ?? ProfileService();

  final ProfileService _profileService;

  UserProfile? profile;
  bool isLoading = false;
  bool isSaving = false;
  bool isUploadingAvatar = false;
  String? errorMessage;

  Future<UserProfile?> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      profile = await _profileService.getCurrentUser();
      return profile;
    } on ProfileException catch (error) {
      errorMessage = error.message;
    } on FormatException catch (error) {
      errorMessage = error.message;
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
    } finally {
      isUploadingAvatar = false;
      notifyListeners();
    }
    return null;
  }
}
