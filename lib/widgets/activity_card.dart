import 'package:flutter/material.dart';
import 'package:llamalla/widgets/pending_sync_badge.dart';

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
    final venue = activity.aboutLocation ?? activity.locationName ?? '';
    final fraction = activity.spotsFraction;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero image with the category and price chips on top.
          Stack(
            children: [
              _ActivityImage(url: activity.imageUrl, height: compact ? 90 : 130),
              Positioned(
                left: 10,
                top: 10,
                child: _Pill(
                  text: activity.category,
                  color: AppColors.yellow.withValues(alpha: 0.9),
                ),
              ),
              if (activity.price.isNotEmpty)
                Positioned(
                  right: 10,
                  top: 10,
                  child: _Pill(text: activity.price, color: AppColors.white),
                ),
              if (activity.isPendingSync)
                const Positioned(
                  left: 10,
                  bottom: 10,
                  child: PendingSyncBadge(),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        activity.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (activity.fitsWindow)
                      const Icon(Icons.check_circle,
                          size: 16, color: AppColors.green),
                  ],
                ),
                if (venue.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    venue,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.grey),
                  ),
                ],
                const SizedBox(height: 7),
                Wrap(
                  spacing: 9,
                  runSpacing: 5,
                  children: [
                    if (activity.distance.isNotEmpty)
                      InfoChip(
                          icon: Icons.location_on_outlined,
                          text: activity.distance),
                    InfoChip(
                        icon: Icons.schedule_outlined, text: activity.duration),
                    InfoChip(
                        icon: Icons.group_outlined, text: activity.spotsLabel),
                  ],
                ),
                if (fraction != null) ...[
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 5,
                      backgroundColor: AppColors.blue.withValues(alpha: 0.25),
                      color: fraction >= 0.9
                          ? AppColors.rosewood
                          : AppColors.green,
                    ),
                  ),
                ],
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

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ActivityImage extends StatelessWidget {
  const _ActivityImage({required this.url, required this.height});

  final String url;
  final double height;

  Widget get _placeholder => Container(
    color: AppColors.blue.withValues(alpha: 0.30),
    child: const Center(child: Icon(Icons.image_outlined, size: 34)),
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: url.isEmpty
          ? _placeholder
          : Image.network(
        url, // #31 will swap this for CachedNetworkImage
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder,
      ),
    );
  }
}