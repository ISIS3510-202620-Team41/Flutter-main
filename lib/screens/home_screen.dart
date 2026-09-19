import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';
import '../widgets/header.dart';
import '../widgets/activity_card.dart';
import '../widgets/section_title.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.onOpenFlow});

  final VoidCallback? onOpenFlow;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Header(onAdd: onOpenFlow),
            const SizedBox(height: 18),
            const Text('Hola, Juan 👋', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            const Text('Aprovecha tu próxima ventana libre', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 14),
            _FreeWindowCard(),
            const SizedBox(height: 20),
            const SectionTitle('Actividades recomendadas'),
            const SizedBox(height: 10),
            ActivityCard(
              activity: bistro,
              onChoose: () => Navigator.pushNamed(context, '/activity-detail'),
            ),
            const SizedBox(height: 12),
            ActivityCard(activity: pokeAndDraw),
          ],
        ),
      ),
    );
  }
}

class _FreeWindowCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.blue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Tiempo libre disponible', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                SizedBox(height: 7),
                Text('92 min', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                SizedBox(height: 3),
                Text('11:30 AM — 1:00 PM', style: TextStyle(fontSize: 11)),
                SizedBox(height: 8),
                Text('Próx: Diseño de aplicaciones', style: TextStyle(fontSize: 10)),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('92', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
