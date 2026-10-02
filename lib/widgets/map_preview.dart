import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MapPreview extends StatelessWidget {
  const MapPreview({
    super.key,
    this.height = 120,
    this.markerLabel = 'Bistro',
  });

  final double height;
  final String markerLabel;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: height,
        color: AppColors.blue.withValues(alpha: 0.32),
        child: CustomPaint(
          painter: _MapPainter(),
          child: Stack(
            children: [
              Positioned(
                left: 88,
                top: height * 0.33,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(markerLabel, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
                    ),
                    const Icon(Icons.location_on, color: AppColors.rosewood, size: 30),
                  ],
                ),
              ),
              Positioned(
                right: 12,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Text('Campus universitario', style: TextStyle(fontSize: 9)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1;

    for (double x = 22; x < size.width; x += 38) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    for (double y = 18; y < size.height; y += 34) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final roadPaint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.85)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.75),
      Offset(size.width * 0.82, size.height * 0.20),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.50, 0),
      Offset(size.width * 0.50, size.height),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
