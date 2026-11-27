import 'package:flutter/material.dart';

import '../database/local_database_facade.dart';
import '../models/activity.dart';
import '../models/joined_activity_record.dart';
import '../navigation/app_routes.dart';
import '../theme/app_theme.dart';
import '../viewmodels/joined_activities_view_model.dart';

class MyJoinedActivitiesScreen extends StatefulWidget {
  const MyJoinedActivitiesScreen({super.key});

  @override
  State<MyJoinedActivitiesScreen> createState() =>
      _MyJoinedActivitiesScreenState();
}

class _MyJoinedActivitiesScreenState extends State<MyJoinedActivitiesScreen> {
  late final JoinedActivitiesViewModel _viewModel = JoinedActivitiesViewModel(
    LocalDatabaseFacade.instance.joinedActivities ??
        (throw StateError('The local database has not been initialized.')),
  )..load();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _openActivity(JoinedActivityRecord enrollment) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.activityDetail,
      arguments: enrollment.activity.id,
    );
    if (mounted) await _viewModel.refresh();
  }

  Future<void> _leaveActivity(JoinedActivityRecord enrollment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salir de la actividad'),
        content: Text(
          '¿Quieres cancelar tu inscripción a "${enrollment.activity.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Mantener inscripción'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _viewModel.leaveActivity(enrollment);
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Regresar',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mis actividades',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              Text(
                'Consulta las actividades en las que participas',
                style: TextStyle(fontSize: 10, color: AppColors.grey),
              ),
            ],
          ),
          actions: [
            if (_viewModel.isOffline)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Icon(Icons.wifi_off, color: AppColors.blue),
              )
            else if (_viewModel.isRefreshing)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                tooltip: 'Actualizar mis actividades',
                onPressed: _viewModel.refresh,
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.activities.isEmpty) {
      return const _LoadingList();
    }

    return RefreshIndicator(
      onRefresh: _viewModel.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
        children: [
          if (_viewModel.isOffline)
            const _NoticeBanner(
              icon: Icons.wifi_off,
              title: 'Estás sin conexión',
              message: 'Mostrando los últimos datos disponibles.',
              color: AppColors.blueLight,
            ),
          if (_viewModel.refreshError != null)
            _NoticeBanner(
              icon: Icons.error_outline,
              title: 'No pudimos actualizar la información',
              message:
                  'Tus actividades guardadas siguen disponibles. '
                  '${_viewModel.refreshError}',
              color: const Color(0xFFFFF4D6),
              action: TextButton(
                onPressed: _viewModel.refresh,
                child: const Text('Reintentar'),
              ),
            ),
          if (_viewModel.errorMessage != null)
            _NoticeBanner(
              icon: Icons.error_outline,
              title: 'No pudimos cargar tus actividades',
              message: _viewModel.errorMessage!,
              color: AppColors.rosewood.withValues(alpha: 0.1),
              action: TextButton(
                onPressed: _viewModel.load,
                child: const Text('Reintentar'),
              ),
            ),
          if (_viewModel.isEmpty)
            _EmptyState(onExplore: () => Navigator.maybePop(context))
          else ...[
            _SectionHeader(
              title: 'Próximas actividades',
              count: _viewModel.upcomingActivities.length,
            ),
            const SizedBox(height: 10),
            if (_viewModel.upcomingActivities.isEmpty)
              const _SectionEmpty(text: 'No tienes actividades próximas.')
            else
              ..._viewModel.upcomingActivities.map(
                (enrollment) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ActivityCard(
                    enrollment: enrollment,
                    onOpen: () => _openActivity(enrollment),
                    onLeave: () => _leaveActivity(enrollment),
                    onRetry: () => _viewModel.retryAction(enrollment),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Semantics(
              button: true,
              expanded: _viewModel.pastActivitiesExpanded,
              label: 'Actividades pasadas, ${_viewModel.pastActivities.length}',
              child: OutlinedButton(
                onPressed: _viewModel.togglePastActivities,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.black,
                  side: BorderSide(
                    color: AppColors.black.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Actividades pasadas '
                        '(${_viewModel.pastActivities.length})',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Icon(
                      _viewModel.pastActivitiesExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                    ),
                  ],
                ),
              ),
            ),
            if (_viewModel.pastActivitiesExpanded) ...[
              const SizedBox(height: 10),
              if (_viewModel.pastActivities.isEmpty)
                const _SectionEmpty(text: 'No tienes actividades pasadas.')
              else
                ..._viewModel.pastActivities.map(
                  (enrollment) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ActivityCard(
                      enrollment: enrollment,
                      onOpen: () => _openActivity(enrollment),
                      onLeave: () => _leaveActivity(enrollment),
                      onRetry: () => _viewModel.retryAction(enrollment),
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.enrollment,
    required this.onOpen,
    required this.onLeave,
    required this.onRetry,
  });

  final JoinedActivityRecord enrollment;
  final VoidCallback onOpen;
  final VoidCallback onLeave;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final activity = enrollment.activity;
    final state = _statusPresentation(enrollment);
    final start = DateTime.tryParse(activity.startTime);

    return Card(
      color: AppColors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE8F4FB)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.blueLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      categoryLabel(activity.category).isEmpty
                          ? '?'
                          : categoryLabel(activity.category)[0],
                      style: const TextStyle(
                        color: AppColors.blue,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            _Metadata(
                              icon: Icons.calendar_today_outlined,
                              text: _formatDateTime(start),
                            ),
                            _Metadata(
                              icon: Icons.location_on_outlined,
                              text: activity.locationName,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _StatusBadge(
                          presentation: state,
                          syncStatus: enrollment.syncStatus,
                        ),
                        const SizedBox(height: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4D6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            categoryLabel(activity.category),
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.grey),
                ],
              ),
            ),
          ),
          if (enrollment.syncStatus == JoinedSyncStatus.failed)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Reintentar'),
              ),
            )
          else if (!enrollment.isPast && !enrollment.isPendingLeave)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onLeave,
                child: const Text('Salir de actividad'),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusPresentation {
  const _StatusPresentation({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    this.hint,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  final String? hint;
}

_StatusPresentation _statusPresentation(JoinedActivityRecord enrollment) {
  if (enrollment.isPendingLeave) {
    if (enrollment.syncStatus == JoinedSyncStatus.failed) {
      return _StatusPresentation(
        icon: Icons.error_outline,
        label: 'Salida pendiente de sincronizar',
        color: AppColors.rosewood,
        background: AppColors.rosewood.withValues(alpha: 0.1),
        hint: enrollment.lastError ?? 'No se pudo cancelar la inscripción.',
      );
    }
    return _StatusPresentation(
      icon: enrollment.syncStatus == JoinedSyncStatus.processing
          ? Icons.sync
          : Icons.schedule,
      label: enrollment.syncStatus == JoinedSyncStatus.processing
          ? 'Sincronizando salida'
          : 'Salida pendiente de sincronizar',
      color: AppColors.blue,
      background: AppColors.blueLight,
      hint: 'Seguirás inscrito hasta que se confirme la salida.',
    );
  }
  if (enrollment.isPendingJoin) {
    if (enrollment.syncStatus == JoinedSyncStatus.processing) {
      return const _StatusPresentation(
        icon: Icons.sync,
        label: 'Sincronizando inscripción',
        color: AppColors.blue,
        background: AppColors.blueLight,
      );
    }
    return _StatusPresentation(
      icon: enrollment.syncStatus == JoinedSyncStatus.failed
          ? Icons.error_outline
          : Icons.schedule,
      label: 'Pendiente de sincronizar',
      color: enrollment.syncStatus == JoinedSyncStatus.failed
          ? AppColors.rosewood
          : AppColors.black,
      background: enrollment.syncStatus == JoinedSyncStatus.failed
          ? AppColors.rosewood.withValues(alpha: 0.1)
          : const Color(0xFFFFF4D6),
      hint: enrollment.syncStatus == JoinedSyncStatus.failed
          ? enrollment.lastError ?? 'No se pudo enviar la inscripción.'
          : 'Se sincronizará cuando recuperes la conexión.',
    );
  }
  return const _StatusPresentation(
    icon: Icons.check_circle_outline,
    label: 'Inscripción confirmada',
    color: Color(0xFF16834A),
    background: Color(0xFFE9F8EF),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.presentation, required this.syncStatus});

  final _StatusPresentation presentation;
  final JoinedSyncStatus syncStatus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: presentation.background,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (syncStatus == JoinedSyncStatus.processing)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: presentation.color,
                  ),
                )
              else
                Icon(presentation.icon, size: 14, color: presentation.color),
              const SizedBox(width: 5),
              Text(
                presentation.label,
                style: TextStyle(
                  fontSize: 10,
                  color: presentation.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (presentation.hint != null) ...[
          const SizedBox(height: 3),
          Text(
            presentation.hint!,
            style: const TextStyle(fontSize: 10, color: AppColors.grey),
          ),
        ],
      ],
    );
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.blue),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 10, color: AppColors.grey)),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
        CircleAvatar(
          radius: 13,
          backgroundColor: AppColors.blueLight,
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.blue,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(message, style: const TextStyle(fontSize: 10)),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(text, style: const TextStyle(color: AppColors.grey)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 58),
      child: Column(
        children: [
          const Icon(
            Icons.event_available_outlined,
            size: 60,
            color: AppColors.blue,
          ),
          const SizedBox(height: 14),
          const Text(
            'Todavía no estás inscrito en ninguna actividad',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Explora las actividades del campus y encuentra una que encaje contigo.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.grey),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onExplore,
            child: const Text('Explorar actividades'),
          ),
        ],
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: List.generate(
        3,
        (_) => const Card(
          child: SizedBox(
            height: 132,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime? date) {
  if (date == null) return 'Fecha por confirmar';
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'p. m.' : 'a. m.';
  return '$day/$month · $hour:$minute $period';
}
