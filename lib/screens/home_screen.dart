import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models/profile_models.dart';
import '../theme/app_theme.dart';
import '../widgets/header.dart';
import '../widgets/activity_card.dart';
import '../widgets/section_title.dart';
import '../viewmodels/home_view_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onOpenFlow});

  final VoidCallback? onOpenFlow;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeViewModel _viewModel = HomeViewModel()..load();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Header(onAdd: widget.onOpenFlow),
              const SizedBox(height: 18),
              Text(
                'Hola, ${_viewModel.greetingName} 👋',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              const Text('Aprovecha tu próxima ventana libre', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 14),
              if (_viewModel.isLoading)
                const SizedBox(
                  height: 150,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_viewModel.errorMessage != null)
                _ErrorCard(
                  message: _viewModel.errorMessage!,
                  onRetry: _viewModel.load,
                )
              else
                _FreeWindowCard(interval: _viewModel.nextFreeInterval),
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
      ),
    );
  }
}

class _FreeWindowCard extends StatelessWidget {
  const _FreeWindowCard({required this.interval});

  final FreeInterval? interval;

  @override
  Widget build(BuildContext context) {
    final availableMinutes = interval == null
        ? 0
        : interval!.end.difference(interval!.start).inMinutes;
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
              children: [
                const Text('Tiempo libre disponible', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 7),
                Text(
                  interval == null ? 'Sin ventanas' : '$availableMinutes min',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  interval == null
                      ? 'Revisa tu horario para encontrar tiempo libre'
                      : '${formatClockTime(interval!.start)} — ${formatClockTime(interval!.end)}',
                  style: const TextStyle(fontSize: 11),
                ),
                const SizedBox(height: 8),
                Text(
                  interval == null ? 'No hay tiempo libre próximo' : 'Próxima ventana disponible',
                  style: const TextStyle(fontSize: 10),
                ),
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
            child: Text(
              interval == null ? '—' : '$availableMinutes',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.rosewood.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(child: Text(message, style: const TextStyle(fontSize: 12))),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
