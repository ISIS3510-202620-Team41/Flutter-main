import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PendingSyncBadge extends StatelessWidget {
  const PendingSyncBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.rosewood,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, size: 11, color: AppColors.white),
          SizedBox(width: 4),
          Text(
            'Pendiente de sincronizar',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}