import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../theme/app_theme.dart';
import '../widgets/map_preview.dart';

class ActivityCreatedScreen extends StatelessWidget {
  const ActivityCreatedScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                child: Image.network(
                  bistro.imageUrl,
                  height: 144,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 144,
                    color: AppColors.blue.withValues(alpha: 0.35),
                    child: const Icon(Icons.image_outlined, size: 38),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Bistro', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('500 m · 2 h estimadas', style: TextStyle(fontSize: 11)),
              const SizedBox(height: 12),
              const Text('Amigos confirmados', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: const [
                  CircleAvatar(radius: 14, child: Text('L', style: TextStyle(fontSize: 10))),
                  CircleAvatar(radius: 14, child: Text('R', style: TextStyle(fontSize: 10))),
                  CircleAvatar(radius: 14, child: Text('B', style: TextStyle(fontSize: 10))),
                  CircleAvatar(radius: 14, child: Text('Tú', style: TextStyle(fontSize: 8))),
                  Padding(
                    padding: EdgeInsets.only(left: 2, top: 5),
                    child: Text('Lucía, Rini, Ben, Tú', style: TextStyle(fontSize: 10)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Ubicación', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('Bistro', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              const Text('Campus universitario', style: TextStyle(fontSize: 10)),
              const Text('DiPico', style: TextStyle(fontSize: 10)),
              const SizedBox(height: 8),
              const MapPreview(height: 128, markerLabel: 'Bistro'),
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
                    Text('Cabe en tu tiempo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
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
