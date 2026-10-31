import 'package:flutter/material.dart';
import 'dart:io';
import '../models/activity.dart';
import '../models/activity_record.dart';
import '../theme/app_theme.dart';
import '../widgets/info_chip.dart';
import '../widgets/map_preview.dart';
import '../viewmodels/activity_view_models.dart';

class ActivityDetailScreen extends StatefulWidget {
  const ActivityDetailScreen({
    super.key,
    required this.activityId,
  });

  final String? activityId;

  @override
  State<ActivityDetailScreen> createState() =>
      _ActivityDetailScreenState();
}

class _ActivityDetailScreenState
    extends State<ActivityDetailScreen> {
  late final ActivityDetailViewModel _viewModel;

  @override
  void initState() {
    super.initState();

    _viewModel = ActivityDetailViewModel()
      ..load(widget.activityId);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _viewModel,
          builder: (context, _) {
            final activity = _viewModel.activity;

            if (activity == null) {
              return _buildLoadingOrError();
            }

            return _buildActivityDetail(activity);
          },
        ),
      ),
    );
  }

  Widget _buildLoadingOrError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_viewModel.isLoading)
              const CircularProgressIndicator()
            else
              const Icon(
                Icons.error_outline,
                size: 40,
              ),
            const SizedBox(height: 12),
            Text(
              _viewModel.isLoading
                  ? 'Cargando actividad...'
                  : _viewModel.errorMessage ??
                      'No se pudo cargar la actividad.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
            if (!_viewModel.isLoading) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: _viewModel.retry,
                child: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActivityDetail(ActivityRecord activity) {
    return SingleChildScrollView(
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
                child: Text(
                  categoryLabel(activity.category),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),

          if (_viewModel.isRefreshing)
            const LinearProgressIndicator(),

          if (_viewModel.refreshErrorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.yellow.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _viewModel.refreshErrorMessage!,
                      style: const TextStyle(fontSize: 11),
                    ),
                    TextButton(
                      onPressed: _viewModel.retry,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),

          _buildImage(activity),

          const SizedBox(height: 10),

          Text(
            activity.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 9),

          Wrap(
            spacing: 14,
            runSpacing: 9,
            children: [
              InfoChip(
                icon: Icons.location_on_outlined,
                text: _formatDistance(activity.distanceKm),
              ),
              InfoChip(
                icon: Icons.attach_money,
                text: activity.price ?? 'Precio no informado',
              ),
              InfoChip(
                icon: Icons.schedule_outlined,
                text: _formatDuration(activity),
              ),
              InfoChip(
                icon: Icons.group_outlined,
                text: _formatParticipants(activity),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _sectionTitle('Horario'),

          const SizedBox(height: 7),

          Text(
            '${_formatDateTime(activity.startTime)}\n'
            '${_formatDateTime(activity.endTime)}',
            style: const TextStyle(
              fontSize: 11,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 16),

          _sectionTitle('Descripción'),

          const SizedBox(height: 7),

          Text(
            activity.description?.trim().isNotEmpty == true
                ? activity.description!
                : 'No hay una descripción disponible.',
            style: const TextStyle(
              fontSize: 11,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 16),

          _sectionTitle('Sobre el lugar'),

          const SizedBox(height: 7),

          Text(
            activity.aboutLocation?.trim().isNotEmpty == true
                ? activity.aboutLocation!
                : 'No hay información adicional del lugar.',
            style: const TextStyle(
              fontSize: 11,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 16),

          _sectionTitle('Ubicación'),

          const SizedBox(height: 7),

          Text(
            activity.locationName,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          MapPreview(
            height: 142,
            markerLabel: activity.locationName,
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/activity/create',
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.rosewood,
                foregroundColor: AppColors.white,
                minimumSize: const Size.fromHeight(42),
              ),
              child: Text(
                'Elegir ${activity.title} →',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(ActivityRecord activity) {
    final localPath = activity.localImagePath;

    if (localPath != null && localPath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          File(localPath),
          height: 170,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _networkImage(activity),
        ),
      );
    }

    return _networkImage(activity);
  }

  Widget _networkImage(ActivityRecord activity) {
    final imageUrl = activity.imageUrl?.trim() ?? '';

    if (imageUrl.isEmpty) {
      return _imagePlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        imageUrl,
        height: 170,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _imagePlaceholder(),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 170,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(
        Icons.image_outlined,
        size: 42,
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  String _formatDistance(double? distanceKm) {
    if (distanceKm == null) return 'Distancia n/d';

    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    }

    return '${distanceKm.toStringAsFixed(1)} km';
  }

  String _formatDuration(ActivityRecord activity) {
    final start = DateTime.tryParse(activity.startTime);
    final end = DateTime.tryParse(activity.endTime);

    if (start == null || end == null) {
      return 'Duración n/d';
    }

    final minutes = end.difference(start).inMinutes;

    if (minutes < 0) return 'Duración n/d';
    if (minutes < 60) return '$minutes min';

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    return remainingMinutes == 0
        ? '$hours h'
        : '$hours h $remainingMinutes min';
  }

  String _formatParticipants(ActivityRecord activity) {
    if (activity.capacity == null) {
      return '${activity.participants} inscritos';
    }

    return '${activity.participants}/${activity.capacity} participantes';
  }

  String _formatDateTime(String value) {
    final date = DateTime.tryParse(value);

    if (date == null) return value;

    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;

    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/$year · $hour:$minute $period';
  }
}