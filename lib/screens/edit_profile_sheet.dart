import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../utils/media_url.dart';

void showEditProfile({
  required BuildContext context,
  required String currentName,
  required String currentDescription,
  required Future<String?> Function(String name, String description) onSave,
  String? currentAvatarUrl,
  String? currentLocalAvatarPath,
  required Future<String?> Function(ImageSource source) onPickImage,
  Future<void> Function()? onExportAvatar,
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
      currentLocalAvatarPath: currentLocalAvatarPath,
      onPickImage: onPickImage,
      onExportAvatar: onExportAvatar,
    ),
  );
}

class EditProfileContent extends StatefulWidget {
  final String currentName;
  final String currentDescription;
  final Future<String?> Function(String, String) onSave;
  final String? currentAvatarUrl;
  final String? currentLocalAvatarPath;
  final Future<String?> Function(ImageSource source) onPickImage;
  final Future<void> Function()? onExportAvatar;

  const EditProfileContent({
    super.key,
    required this.currentName,
    required this.currentDescription,
    required this.onSave,
    this.currentAvatarUrl,
    this.currentLocalAvatarPath,
    required this.onPickImage,
    this.onExportAvatar,
  });

  @override
  State<EditProfileContent> createState() => _EditProfileContentState();
}

class _EditProfileContentState extends State<EditProfileContent> {
  late TextEditingController nameController;
  late TextEditingController descriptionController;
  final urlController = TextEditingController();
  String? avatarUrl;
  String? localAvatarPath;
  bool uploadingPhoto = false;
  bool exportingPhoto = false;
  bool saving = false;
  String? formError; // error que se muestra dentro del sheet

  @override
  void initState() {
    super.initState();
    // Start with what the profile already had
    avatarUrl = widget.currentAvatarUrl;
    localAvatarPath = widget.currentLocalAvatarPath;
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

  Future<void> _chooseImageSource() async {
    if (uploadingPhoto) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Elegir de galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickPhoto(source);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (uploadingPhoto) return;
    setState(() {
      uploadingPhoto = true;
      formError = null;
    });
    String? newPath;
    String? error;
    try {
      newPath = await widget.onPickImage(source);
    } catch (e) {
      error = e.toString();
    }
    if (!mounted) return;
    setState(() {
      uploadingPhoto = false;
      formError = error;
      if (newPath != null) localAvatarPath = newPath;
    });
  }

  Future<void> _exportPhoto() async {
    final export = widget.onExportAvatar;
    if (export == null || exportingPhoto) return;
    setState(() => exportingPhoto = true);
    try {
      await export();
    } finally {
      if (mounted) setState(() => exportingPhoto = false);
    }
  }

  // Guarda y cierra el sheet. Si falla, muestra el error acá mismo
  // (un SnackBar quedaría escondido detrás del sheet).
  Future<void> _save() async {
    setState(() {
      saving = true;
      formError = null;
    });
    final error = await widget.onSave(
      nameController.text,
      descriptionController.text,
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      saving = false;
      formError = error;
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
                    backgroundImage: localAvatarPath != null
                        ? FileImage(File(localAvatarPath!))
                        : avatarUrl != null
                        ? NetworkImage(resolveMediaUrl(avatarUrl)!)
                        : null,
                    child: localAvatarPath != null || avatarUrl != null
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
                      onTap: _chooseImageSource,
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
                                Icons.add_a_photo,
                                size: 12,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.onExportAvatar != null &&
                (localAvatarPath != null || avatarUrl != null))
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  onPressed: exportingPhoto ? null : _exportPhoto,
                  icon: exportingPhoto
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined, size: 16),
                  label: const Text('Guardar foto en el dispositivo'),
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
            if (formError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  formError!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.rosewood,
                  ),
                ),
              ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.rosewood,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
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
