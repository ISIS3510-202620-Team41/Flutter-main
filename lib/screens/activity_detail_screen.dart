import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../theme/app_theme.dart';
import '../widgets/info_chip.dart';
import '../widgets/map_preview.dart';

class ActivityDetailScreen extends StatelessWidget {
  const ActivityDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Container(
                      alignment: Alignment.center,
                      child: const Text('Comida', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  bistro.imageUrl,
                  height: 170,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 170,
                    color: AppColors.blue.withValues(alpha: 0.35),
                    child: const Icon(Icons.image_outlined, size: 42),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text('Bistro', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 9),
              Wrap(
                spacing: 14,
                runSpacing: 9,
                children: const [
                  InfoChip(icon: Icons.location_on_outlined, text: '500 m'),
                  InfoChip(icon: Icons.attach_money, text: '\$12K'),
                  InfoChip(icon: Icons.schedule_outlined, text: '20–30 min'),
                  InfoChip(icon: Icons.group_outlined, text: '1+ persona'),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.access_time, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ventana disponible: 92 min\n11:30 AM — 1:00 PM · Esta actividad encaja',
                        style: TextStyle(fontSize: 11, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Sobre el lugar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 7),
              const Text(
                'Café universitario con menú del día, ensaladas y postres. Ambiente tranquilo ideal para comer rápido o estudiar entre clases. WiFi disponible.',
                style: TextStyle(fontSize: 11, height: 1.45),
              ),
              const SizedBox(height: 16),
              const Text('Ubicación', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 7),
              const Text('Bistro', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              const Text('Campus universitario DiPico', style: TextStyle(fontSize: 10)),
              const SizedBox(height: 8),
              const MapPreview(height: 142, markerLabel: 'Bistro'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pushNamed(context, '/activity/create'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.rosewood,
                    foregroundColor: AppColors.white,
                    minimumSize: const Size.fromHeight(42),
                  ),
                  child: const Text('Elegir Bistro →', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.rosewood,
                    side: const BorderSide(color: AppColors.rosewood),
                    minimumSize: const Size.fromHeight(40),
                  ),
                  icon: const Icon(Icons.group_outlined, size: 16),
                  label: const Text('Compartir con amigos', style: TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
