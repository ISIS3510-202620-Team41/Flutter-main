
import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../widgets/header.dart';
import '../widgets/info_chip.dart';
import '../widgets/map_preview.dart';
import '../viewmodels/activity_view_models.dart';
import '../widgets/pending_sync_badge.dart';
import '../widgets/category_preferences_sheet.dart';


class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key, this.onOpenDetail});

  final ValueChanged<String>? onOpenDetail;

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  late final _viewModel = ActivitiesViewModel()..load();

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
        builder: (context, _) {
          return StreamBuilder<List<Activity>>(
            stream: _viewModel.activitiesStream,
            builder: (context, snapshot) {
              final source =
                  snapshot.data ?? _viewModel.activities;

              // Aplicamos los filtros seleccionados por el usuario.
              final visibleActivities =
                  _viewModel.filterActivities(source);

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Header(
                      onAdd: () => Navigator.pushNamed(
                        context,
                        '/activity/create',
                      ),
                    ),

                    const SizedBox(height: 18),

                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Actividades cerca de ti',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              showCategoryPreferencesSheet(context),
                          icon: const Icon(Icons.tune, size: 16),
                          label: const Text(
                            'Mis categorías',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    MapPreview(
                      height: 126,
                      markerLabel: visibleActivities.isEmpty
                          ? 'Tú'
                          : (visibleActivities.first.locationName ??
                              visibleActivities.first.name),
                    ),

                    const SizedBox(height: 9),

                    // Advertencias relacionadas con la ubicación.
                    if (_viewModel.locationWarning != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _viewModel.locationWarning!,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),

                          if (_viewModel.locationIssue ==
                              LocationIssue.permissionDeniedForever)
                            TextButton(
                              onPressed: () {
                                _viewModel.openAppSettings();
                              },
                              child: const Text('Ajustes'),
                            ),

                          if (_viewModel.locationIssue ==
                              LocationIssue.serviceDisabled)
                            TextButton(
                              onPressed: () {
                                _viewModel.openLocationSettings();
                              },
                              child: const Text('Activar GPS'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 9),
                    ],

                    // Filtros por categoría.
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ActivitiesViewModel.categories
                            .map(
                              (label) => Padding(
                                padding:
                                    const EdgeInsets.only(right: 6),
                                child: SizedBox(
                                  width: 100,
                                  child: _CategoryPill(
                                    label: label,
                                    selected:
                                        _viewModel.selectedCategory ==
                                            label,
                                    onTap: () =>
                                        _viewModel.selectCategory(label),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Buscador.
                    TextField(
                      onChanged: _viewModel.setQuery,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(
                          Icons.search,
                          size: 18,
                        ),
                        hintText: 'Buscar',
                        hintStyle: TextStyle(fontSize: 11),
                      ),
                    ),

                    const SizedBox(height: 9),

                    // Filtros adicionales.
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: const [
                          _FilterChip(
                            label: 'Distancia',
                            icon: Icons.location_on_outlined,
                          ),
                          _FilterChip(
                            label: 'Tiempo',
                            icon: Icons.schedule_outlined,
                          ),
                          _FilterChip(
                            label: 'Personas',
                            icon: Icons.group_outlined,
                          ),
                          _FilterChip(
                            label: 'Presupuesto',
                            icon: Icons.attach_money,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Estados de carga, error y lista de actividades.
                    if (snapshot.hasError &&
                        visibleActivities.isEmpty)
                      const Center(
                        child: Text(
                          'Error al actualizar las actividades.',
                          style: TextStyle(fontSize: 12),
                        ),
                      )
                    else if (_viewModel.isLoading &&
                        visibleActivities.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 30),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_viewModel.errorMessage != null &&
                        visibleActivities.isEmpty)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _viewModel.errorMessage!,
                              style:
                                  const TextStyle(fontSize: 12),
                            ),
                          ),
                          TextButton(
                            onPressed: _viewModel.load,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      )
                    else if (visibleActivities.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: Center(
                          child: Text(
                            'No hay actividades cerca con esos filtros.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                    else
                      ...visibleActivities.map((activity) {
                        final activityId = activity.id;

                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: 9),
                          child: _ActivityRow(
                            activity: activity,
                            onTap: activityId == null
                                ? null
                                : () => widget.onOpenDetail
                                    ?.call(activityId),
                          ),
                        );
                      }),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.rosewood : AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppColors.rosewood
                : AppColors.black.withValues(alpha: 0.12),
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
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.black.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.activity,
    this.onTap,
  });

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
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.yellow,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          activity.category,
                          style: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 5),
                  if (activity.isPendingSync) ...[
                    const SizedBox(height: 5),
                    const PendingSyncBadge(),
                  ],

                  Wrap(
                    spacing: 8,
                    children: [
                      InfoChip(
                        icon: Icons.group_outlined,
                        text: activity.people,
                      ),
                      if (activity.price.isNotEmpty)
                        InfoChip(
                          icon: Icons.attach_money,
                          text: activity.price,
                        ),
                      InfoChip(
                        icon: Icons.schedule_outlined,
                        text: activity.duration,
                      ),
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
              child: const Text(
                'Ver →',
                style: TextStyle(fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
