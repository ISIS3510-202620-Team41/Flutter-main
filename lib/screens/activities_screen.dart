import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/activity.dart';
import '../theme/app_theme.dart';
import '../widgets/header.dart';
import '../widgets/info_chip.dart';
import '../widgets/map_preview.dart';

class ActivitiesScreen extends StatelessWidget {
  const ActivitiesScreen({super.key, this.onOpenDetail});

  final VoidCallback? onOpenDetail;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Header(onAdd: () => Navigator.pushNamed(context, '/activity/create')),
            const SizedBox(height: 18),
            const Text('Actividades cerca de ti', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            const MapPreview(height: 126, markerLabel: 'Bistro'),
            const SizedBox(height: 9),
            Row(
              children: const [
                Expanded(child: _CategoryPill(label: 'Comida', selected: true)),
                SizedBox(width: 6),
                Expanded(child: _CategoryPill(label: 'Manualidades')),
                SizedBox(width: 6),
                Expanded(child: _CategoryPill(label: 'Descanso')),
              ],
            ),
            const SizedBox(height: 8),
            const TextField(
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search, size: 18),
                hintText: 'Buscar',
                hintStyle: TextStyle(fontSize: 11),
              ),
            ),
            const SizedBox(height: 9),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: const [
                  _FilterChip(label: 'Distancia', icon: Icons.location_on_outlined),
                  _FilterChip(label: 'Tiempo', icon: Icons.schedule_outlined),
                  _FilterChip(label: 'Personas', icon: Icons.group_outlined),
                  _FilterChip(label: 'Presupuesto', icon: Icons.attach_money),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...nearbyActivities.map((activity) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _ActivityRow(
                    activity: activity,
                    onTap: activity.name == 'Dibujo y Más' ? onOpenDetail : null,
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.rosewood : AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? AppColors.rosewood : AppColors.black.withValues(alpha: 0.12),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: selected ? AppColors.white : AppColors.black,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.black.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity, this.onTap});

  final Activity activity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          activity.name,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.yellow,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(activity.category, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    children: [
                      InfoChip(icon: Icons.group_outlined, text: activity.people),
                      InfoChip(icon: Icons.attach_money, text: activity.price),
                      InfoChip(icon: Icons.schedule_outlined, text: activity.duration),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.rosewood,
                foregroundColor: AppColors.white,
                minimumSize: const Size(52, 30),
                padding: EdgeInsets.zero,
              ),
              child: const Text('Ver →', style: TextStyle(fontSize: 10)),
            ),
          ],
        ),
      ),
    );
  }
}
