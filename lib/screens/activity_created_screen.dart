import 'package:flutter/material.dart';
import '../models/activity.dart';
import '../theme/app_theme.dart';
import '../widgets/map_preview.dart';

class ActivityCreatedScreen extends StatelessWidget {
  const ActivityCreatedScreen({
    super.key,
    required this.activity,
    required this.friends,
    this.savedOffline = false,});

  final Activity activity;
  final List<String> friends;
  final bool savedOffline;

  Widget _imagePlaceholder() => Container(
    height: 144,
    width: double.infinity,
    color: AppColors.blue.withValues(alpha: 0.35),
    child: const Icon(Icons.image_outlined, size: 38),
  );

  @override
  Widget build(BuildContext context) {
    final details = [activity.duration, activity.price]
        .where((text) => text.isNotEmpty)
        .join(' · ');

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                  const Expanded(
                    child: Text(
                      'Actividad creada',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              Center(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: AppColors.green, size: 30),
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: activity.imageUrl.isEmpty
                    ? _imagePlaceholder()
                    : Image.network(
                  activity.imageUrl,
                  height: 144,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _imagePlaceholder(),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                activity.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(details, style: const TextStyle(fontSize: 11)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: [
                  ...friends.map(
                        (name) => CircleAvatar(
                      radius: 14,
                      child: Text(
                        name.isEmpty ? '?' : name[0],
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 2, top: 5),
                    child: Text(
                      '${friends.join(', ')}, Tú',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                activity.locationName ?? '',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
              Text(
                activity.aboutLocation ?? '',
                style: const TextStyle(fontSize: 10),
              ),
              const SizedBox(height: 8),
              MapPreview(height: 128, markerLabel: activity.locationName ?? ''),
              const SizedBox(height: 10),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.black),
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: const Text('Editar', style: TextStyle(fontSize: 10)),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.black),
                    icon: const Icon(Icons.map_outlined, size: 15),
                    label: const Text('Ver ruta', style: TextStyle(fontSize: 10)),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    onPressed: () {},
                    icon: const Icon(Icons.share_outlined, size: 17),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.green, size: 17),
                    SizedBox(width: 7),
                    Text(
                      'Cabe en tu tiempo',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              if (savedOffline)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.yellow.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.cloud_off_outlined, size: 17),
                      SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Actividad guardada localmente. Se sincronizará al reconectar',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}