import 'dart:io';
import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../theme/app_theme.dart';
import 'info_chip.dart';

class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.activity,
    this.onChoose,
    this.compact = false,
    this.isPending = false,
  });

  final Activity activity;
  final VoidCallback? onChoose;
  final bool compact;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (activity.imageUrl.isNotEmpty || (activity.localImagePath?.isNotEmpty ?? false))
            _ActivityImage(url: activity.imageUrl, localPath: activity.localImagePath,)
          else
            Container(
              height: compact ? 72 : 106,
              color: AppColors.blue.withValues(alpha: 0.30),
              child: const Center(
                child: Icon(Icons.image_outlined, size: 34),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.yellow.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        activity.category,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Spacer(),
                    if (activity.fitsWindow)
                      const Icon(Icons.check_circle, size: 16, color: AppColors.green),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  activity.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 9,
                  runSpacing: 5,
                  children: [
                    InfoChip(icon: Icons.location_on_outlined, text: activity.distance),
                    InfoChip(icon: Icons.schedule_outlined, text: activity.duration),
                    if (activity.price.isNotEmpty)
                     InfoChip(icon: Icons.attach_money, text: activity.price),
                    InfoChip(icon: Icons.group_outlined, text: activity.people),
                  ],
                ),
                const SizedBox(height: 9),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: isPending ? null : onChoose,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.rosewood,
                      foregroundColor: AppColors.white,
                      disabledBackgroundColor:
                          AppColors.greenLight,
                      disabledForegroundColor:
                          AppColors.green,
                      minimumSize: const Size.fromHeight(34),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                    ),
                    child: Text(
                      isPending
                          ? 'Inscrito (Pendiente de sincronizar)'
                          : 'Elegir →',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityImage extends StatelessWidget {
  const _ActivityImage({
    required this.url,
    this.localPath,
  });

  final String url;
  final String? localPath;

  @override
  Widget build(BuildContext context) {
    final path = localPath;

    if (path != null && path.isNotEmpty) {
      return Image.file(
        File(path),
        height: 106,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) {
          return _networkImage();
        },
      );
    }

    return _networkImage();
  }

  Widget _networkImage() {
    if (url.isEmpty) {
      return _fallback();
    }

    return Image.network(
      url,
      height: 106,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      height: 106,
      width: double.infinity,
      color: AppColors.blue.withValues(alpha: 0.30),
      child: const Center(
        child: Icon(Icons.broken_image_outlined),
      ),
    );
  }
}