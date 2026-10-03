import 'package:flutter_test/flutter_test.dart';
import 'package:llamalla/models/profile_models.dart';
import 'package:llamalla/services/profile_service.dart';
import 'package:llamalla/viewmodels/profile_view_model.dart';

class _ProfileService extends ProfileService {
  UserProfile profile = const UserProfile(
    id: '1',
    email: 'juan@test.com',
    name: 'Juan Pérez',
    bio: 'Hola',
  );

  @override
  Future<UserProfile> getCurrentUser() async => profile;

  @override
  Future<UserProfile> updateProfile({
    required String name,
    required String bio,
  }) async {
    profile = UserProfile(
      id: profile.id,
      email: profile.email,
      name: name,
      bio: bio,
    );
    return profile;
  }

  @override
  Future<UserProfile> uploadAvatar(String filePath) async {
    profile = UserProfile(
      id: profile.id,
      email: profile.email,
      name: profile.name,
      bio: profile.bio,
      avatarUrl: 'https://example.com/avatar.jpg',
    );
    return profile;
  }
}

void main() {
  test('loads and updates profile through the view model', () async {
    final service = _ProfileService();
    final viewModel = ProfileViewModel(profileService: service);

    await viewModel.load();
    expect(viewModel.profile?.name, 'Juan Pérez');

    await viewModel.updateProfile(name: 'Ana', bio: 'Nueva bio');
    expect(viewModel.profile?.name, 'Ana');
    expect(viewModel.profile?.bio, 'Nueva bio');
    await viewModel.uploadAvatar('/tmp/avatar.jpg');
    expect(viewModel.profile?.avatarUrl, 'https://example.com/avatar.jpg');
    expect(viewModel.errorMessage, isNull);

    viewModel.dispose();
  });
}
