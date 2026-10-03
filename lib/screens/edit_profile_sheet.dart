import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

void showEditProfile({
  required BuildContext context,
  required String currentName,
  required String currentDescription,
  required Future<void> Function(String name, String description) onSave,
  String? currentAvatarUrl,
  required Future<String?> Function() onTakePhoto,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => EditProfileContent(
      currentName: currentName,
      currentDescription: currentDescription,
      onSave: onSave,
      currentAvatarUrl: currentAvatarUrl,
      onTakePhoto: onTakePhoto,
    ),
  );
}

class EditProfileContent extends StatefulWidget {
  final String currentName;
  final String currentDescription;
  final Future<void> Function(String, String) onSave;
  final String? currentAvatarUrl;
  final Future<String?> Function() onTakePhoto;

  const EditProfileContent({
    super.key,
    required this.currentName,
    required this.currentDescription,
    required this.onSave,
    this.currentAvatarUrl,
    required this.onTakePhoto,
  });

  @override
  State<EditProfileContent> createState() => _EditProfileContentState();
}

class _EditProfileContentState extends State<EditProfileContent> {
  late TextEditingController nameController;
  late TextEditingController descriptionController;
  final urlController = TextEditingController();
  String? avatarUrl;
  bool uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    // Start with what the profile already had
    avatarUrl = widget.currentAvatarUrl;
    nameController = TextEditingController(text: widget.currentName);
    descriptionController = TextEditingController(
      text: widget.currentDescription,
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    urlController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    if (uploadingPhoto) return;
    setState(() => uploadingPhoto = true);
    final newUrl = await widget.onTakePhoto();
    if (!mounted) return;
    setState(() {
      uploadingPhoto = false;
      if (newUrl != null) avatarUrl = newUrl;
    });
  }

  InputDecoration fieldStyle({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: AppColors.grey),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE3E8EC)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE3E8EC)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initials = nameController.text.trim().isEmpty
        ? '?'
        : nameController.text
              .trim()
              .split(' ')
              .take(2)
              .map((p) => p[0].toUpperCase())
              .join();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD5D9DD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Edit profile',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: AppColors.blue,
                    backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                    child: avatarUrl != null
                        ? null
                        : Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 26,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: _takePhoto,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.rosewood,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: uploadingPhoto
                            ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Icon(
                          Icons.camera_alt,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // URL field + "Usar" button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: urlController,
                    style: const TextStyle(fontSize: 13),
                    decoration: fieldStyle(hint: 'O pega URL de foto...'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Usar'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'NOMBRE',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.grey,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: nameController,
              onChanged: (_) => setState(() {}),
              decoration: fieldStyle(),
            ),
            const SizedBox(height: 14),
            const Text(
              'DESCRIPCIÓN',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.grey,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: descriptionController,
              maxLines: 3,
              decoration: fieldStyle(),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await widget.onSave(
                    nameController.text,
                    descriptionController.text,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.rosewood,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Guardar cambios',
                  style: TextStyle(fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
