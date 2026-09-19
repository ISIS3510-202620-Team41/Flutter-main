import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/map_preview.dart';

class ActivityDetailScreen extends StatelessWidget {
  const ActivityDetailScreen({
    super.key,
    this.title = 'Bistro',
    this.category = 'Comida',
    this.distance = '500 m',
    this.duration = '20–30 min',
    this.price = '\$12K',
    this.people = '1+ persona',
    this.availabilityWindow = '92 min',
    this.availabilityRange = '11:30 AM – 1:00 PM · Esta actividad encaja',
    this.description =
    'Café universitario con menú del día, ensaladas y postres. Ambiente '
        'tranquilo ideal para comer rápido o estudiar entre clases. WiFi disponible.',
    this.locationLabel = 'Bistro',
    this.onChoose,
    this.onShare,
  });

  final String title;
  final String category;
  final String distance;
  final String duration;
  final String price;
  final String people;
  final String availabilityWindow;
  final String availabilityRange;
  final String description;
  final String locationLabel;
  final VoidCallback? onChoose;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderImage(),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoGrid(),
                    const SizedBox(height: 14),
                    _buildAvailabilityBanner(),
                    const SizedBox(height: 20),
                    const Text(
                      'Sobre el lugar',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.black),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.black.withValues(alpha: 0.65)),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Ubicación',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.black),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: MapPreview(height: 140, markerLabel: locationLabel),
                    ),
                    const SizedBox(height: 22),
                    _buildActions(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildHeaderImage() {
    return SizedBox(
      height: 190,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
         Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3B2F2A), Color(0xFF6B4F3F)],
              ),
            ),
          ),
          Center(
            child: Icon(Icons.storefront, size: 52, color: AppColors.white.withValues(alpha: 0.25)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, AppColors.black.withValues(alpha: 0.6)],
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.yellow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                category,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.black),
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 14,
            child: Text(
              title,
              style: const TextStyle(color: AppColors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
 Widget _buildInfoGrid() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _InfoItem(icon: Icons.location_on, iconColor: AppColors.rosewood, label: 'DISTANCIA', value: distance)),
              Expanded(child: _InfoItem(icon: Icons.schedule, iconColor: AppColors.black, label: 'DURACIÓN', value: duration)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _InfoItem(icon: Icons.savings, iconColor: AppColors.black, label: 'PRECIO', value: price)),
              Expanded(child: _InfoItem(icon: Icons.person, iconColor: AppColors.black, label: 'PERSONAS', value: people)),
            ],
          ),
        ],
      ),
    );
  }
Widget _buildAvailabilityBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.access_time, color: AppColors.blue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ventana disponible: $availabilityWindow',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.black),
                ),
                const SizedBox(height: 2),
                Text(
                  availabilityRange,
                  style: TextStyle(fontSize: 12, color: AppColors.black.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
 Widget _buildActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onChoose,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.rosewood,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: Text('Elegir $title →', style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onShare,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.rosewood),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('Compartir con amigos', style: TextStyle(color: AppColors.rosewood, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.icon, required this.iconColor, required this.label, required this.value});

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.black.withValues(alpha: 0.5), letterSpacing: 0.4),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.black),
            ),
          ],
        ),
      ],
    );
  }
}