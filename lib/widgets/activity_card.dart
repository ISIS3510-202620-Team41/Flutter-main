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
  });

  final Activity activity;
  final VoidCallback? onChoose;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (activity.imageUrl.isNotEmpty)
            _ActivityImage(url: activity.imageUrl)
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
                    InfoChip(icon: Icons.attach_money, text: activity.price),
                    InfoChip(icon: Icons.group_outlined, text: activity.people),
                  ],
                ),
                const SizedBox(height: 9),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onChoose,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.rosewood,
                      foregroundColor: AppColors.white,
                      minimumSize: const Size.fromHeight(34),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                    ),
                    child: const Text('Elegir →', style: TextStyle(fontSize: 12)),
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
  const _ActivityImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 106,
      width: double.infinity,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: AppColors.blue.withValues(alpha: 0.30),
          child: const Center(child: Icon(Icons.broken_image_outlined)),
        ),
      ),
    );
  }
}
