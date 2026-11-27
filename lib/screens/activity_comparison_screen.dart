import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../models/activity_comparison_criteria.dart';
import '../models/activity_comparison_result.dart';
import '../models/activity_record.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../viewmodels/activity_comparison_view_model.dart';

class ActivityComparisonScreen extends StatefulWidget {
  const ActivityComparisonScreen({super.key});

  @override
  State<ActivityComparisonScreen> createState() =>
      _ActivityComparisonScreenState();
}

class _ActivityComparisonScreenState extends State<ActivityComparisonScreen> {
  late final ActivityComparisonViewModel _viewModel =
      ActivityComparisonViewModel()..load();

  bool _criteriaExpanded = false;
  bool _differencesExpanded = false;
  String? _expandedResultId;
  int _activeDifferenceIndex = 0;
  late final PageController _comparisonPageController = PageController();

  @override
  void dispose() {
    _comparisonPageController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _openPicker() async {
    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.white,
      builder: (context) => _ActivityPickerSheet(
        activities: _viewModel.availableActivities,
        selectedIds: _viewModel.selectedActivityIds,
      ),
    );
    if (selected == null || !mounted) return;
    await _viewModel.setSelectedActivityIds(selected);
    if (_activeDifferenceIndex >= _viewModel.selectedActivities.length) {
      _activeDifferenceIndex = 0;
      if (_comparisonPageController.hasClients) {
        _comparisonPageController.jumpToPage(0);
      }
    }
  }

  Future<void> _removeActivity(String id) async {
    await _viewModel.setSelectedActivityIds(
      _viewModel.selectedActivityIds.where((activityId) => activityId != id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              'Comparar actividades',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            Text(
              'Encuentra la opción que mejor se adapta a ti',
              style: TextStyle(fontSize: 10, color: AppColors.grey),
            ),
          ],
        ),
        actions: [
          if (_viewModel.isRefreshing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, _) => _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_viewModel.isOffline)
            _StatusBanner(
              icon: Icons.wifi_off,
              message: 'Sin conexión · Usando actividades guardadas',
              color: AppColors.blueLight,
            ),
          if (_viewModel.locationIssue != null &&
              _viewModel.refreshError != null)
            _StatusBanner(
              icon: Icons.location_off,
              message: _locationIssueMessage(_viewModel.locationIssue!),
              color: const Color(0xFFFFF4D6),
            ),
          if (_viewModel.refreshError != null &&
              _viewModel.locationIssue == null)
            _StatusBanner(
              icon: Icons.info_outline,
              message:
                  'No se pudieron actualizar las actividades. Se conservan los datos locales.',
              color: const Color(0xFFFFF4D6),
              action: TextButton(
                onPressed: _viewModel.isOffline
                    ? null
                    : _viewModel.refreshActivities,
                child: const Text('Reintentar'),
              ),
            ),
          if (_viewModel.isStale && !_viewModel.isOffline)
            const _StatusBanner(
              icon: Icons.schedule,
              message: 'Hay datos locales que podrían estar desactualizados.',
              color: Color(0xFFFFF4D6),
            ),
          if (_viewModel.errorMessage != null)
            _StatusBanner(
              icon: Icons.error_outline,
              message: _viewModel.errorMessage!,
              color: AppColors.rosewood.withValues(alpha: 0.1),
              action: TextButton(
                onPressed: _viewModel.load,
                child: const Text('Reintentar'),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_viewModel.selectedActivityIds.length} de 10 actividades',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed:
                    _viewModel.selectedActivityIds.length >=
                            ActivityComparisonViewModel.maximumActivities ||
                        _viewModel.availableActivities.isEmpty
                    ? null
                    : _openPicker,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Añadir'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _selectionSection(),
          const SizedBox(height: 18),
          if (_viewModel.selectedActivities.length < 2)
            _emptySelection()
          else ...[
            _criteriaPanel(),
            const SizedBox(height: 18),
            if (_viewModel.isCalculating)
              const _LoadingComparison()
            else if (_viewModel.results.isNotEmpty)
              _rankingSection(),
            if (_viewModel.results.isNotEmpty) ...[
              const SizedBox(height: 18),
              _differencesSection(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _selectionSection() {
    final selected = _viewModel.selectedActivities;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Actividades elegidas',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              if (selected.isNotEmpty)
                TextButton(onPressed: _openPicker, child: const Text('Editar')),
            ],
          ),
          if (selected.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Todavía no has añadido actividades.',
                style: TextStyle(fontSize: 12, color: AppColors.grey),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: selected
                  .map(
                    (activity) => InputChip(
                      label: Text(
                        activity.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onDeleted: () => _removeActivity(activity.id),
                      deleteButtonTooltipMessage: 'Quitar ${activity.title}',
                      backgroundColor: AppColors.blueLight,
                      labelStyle: const TextStyle(fontSize: 11),
                    ),
                  )
                  .toList(),
            ),
          if (selected.isNotEmpty &&
              selected.length < ActivityComparisonViewModel.maximumActivities)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _openPicker,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Añadir otra'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptySelection() {
    final count = _viewModel.selectedActivities.length;
    return _SectionCard(
      color: AppColors.white,
      child: Column(
        children: [
          const Icon(Icons.compare_arrows, size: 38, color: AppColors.rosewood),
          const SizedBox(height: 10),
          Text(
            count == 1
                ? 'Añade otra actividad para comparar'
                : 'Elige al menos 2 actividades',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'Podrás ajustar los criterios y ver qué opción se adapta mejor a ti.',
            style: TextStyle(fontSize: 12, color: AppColors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _viewModel.availableActivities.isEmpty
                ? null
                : _openPicker,
            icon: const Icon(Icons.add),
            label: const Text('Añadir actividades'),
          ),
          if (_viewModel.availableActivities.isEmpty)
            TextButton(
              onPressed: _viewModel.refreshActivities,
              child: const Text('Cargar actividades'),
            ),
        ],
      ),
    );
  }

  Widget _criteriaPanel() {
    return _SectionCard(
      color: AppColors.blueLight,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _criteriaExpanded = !_criteriaExpanded),
            child: Row(
              children: [
                const Icon(Icons.tune, color: AppColors.rosewood),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Criterios de comparación',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '6 criterios · Total 100%',
                        style: TextStyle(fontSize: 10, color: AppColors.grey),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_viewModel.criteria.totalWeight}%',
                  style: const TextStyle(
                    color: AppColors.rosewood,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Icon(
                  _criteriaExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Row(
              children: [
                for (final criterion in ActivityComparisonCriterion.values)
                  Expanded(
                    flex: _viewModel.criteria.weights[criterion] ?? 0,
                    child: Container(
                      height: 7,
                      color: _criterionColor(criterion),
                    ),
                  ),
              ],
            ),
          ),
          if (_criteriaExpanded) ...[
            const SizedBox(height: 10),
            for (final criterion in ActivityComparisonCriterion.values)
              _criterionSlider(criterion),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'El peso de los otros criterios se redistribuye automáticamente.',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.black.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _criterionSlider(ActivityComparisonCriterion criterion) {
    final weight = _viewModel.criteria.weights[criterion] ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                criterion.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text('$weight%', style: const TextStyle(fontSize: 11)),
          ],
        ),
        Slider(
          value: weight.toDouble(),
          min: 0,
          max: ActivityComparisonCriteria.maximumWeight.toDouble(),
          divisions: ActivityComparisonCriteria.maximumWeight,
          activeColor: AppColors.rosewood,
          onChanged: (value) =>
              _viewModel.updateWeight(criterion, value.round()),
          onChangeEnd: (_) => _viewModel.commitWeights(),
        ),
        if (criterion == ActivityComparisonCriterion.location)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DropdownButtonFormField<String>(
              initialValue: _viewModel.criteria.preferredLocation ?? '',
              decoration: const InputDecoration(
                labelText: 'Ubicación preferida',
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('Selecciona una ubicación'),
                ),
                ..._viewModel.availableLocations.map(
                  (location) => DropdownMenuItem(
                    value: location,
                    child: Text(location, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (location) => _viewModel.setPreferredLocation(
                location == null || location.isEmpty ? null : location,
              ),
            ),
          ),
      ],
    );
  }

  Widget _rankingSection() {
    final activitiesById = {
      for (final activity in _viewModel.selectedActivities)
        activity.id: activity,
    };
    if (_expandedResultId == null && _viewModel.results.isNotEmpty) {
      _expandedResultId = _viewModel.results.first.activityId;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Tu mejor opción',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            if (_viewModel.isUsingCachedResult)
              const Text(
                'Resultado guardado',
                style: TextStyle(fontSize: 10, color: AppColors.grey),
              ),
          ],
        ),
        const SizedBox(height: 10),
        for (var index = 0; index < _viewModel.results.length; index++)
          if (activitiesById[_viewModel.results[index].activityId] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RankingCard(
                activity: activitiesById[_viewModel.results[index].activityId]!,
                result: _viewModel.results[index],
                position: index + 1,
                expanded:
                    _expandedResultId == _viewModel.results[index].activityId,
                onToggle: () => setState(() {
                  _expandedResultId =
                      _expandedResultId == _viewModel.results[index].activityId
                      ? null
                      : _viewModel.results[index].activityId;
                }),
              ),
            ),
      ],
    );
  }

  Widget _differencesSection() {
    final activities = _viewModel.selectedActivities;
    if (_activeDifferenceIndex >= activities.length) {
      _activeDifferenceIndex = 0;
    }
    final resultsById = {
      for (final result in _viewModel.results) result.activityId: result,
    };
    final bestScores = <ActivityComparisonCriterion, int?>{
      for (final criterion in ActivityComparisonCriterion.values)
        criterion: _bestScore(criterion),
    };

    return _SectionCard(
      child: Column(
        children: [
          InkWell(
            onTap: () =>
                setState(() => _differencesExpanded = !_differencesExpanded),
            child: Row(
              children: [
                const Icon(Icons.compare_arrows, color: AppColors.rosewood),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ver diferencias',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Compara cada detalle',
                        style: TextStyle(fontSize: 10, color: AppColors.grey),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _differencesExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                ),
              ],
            ),
          ),
          if (_differencesExpanded) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Actividad anterior',
                  onPressed: _activeDifferenceIndex == 0
                      ? null
                      : () => _moveComparisonPage(_activeDifferenceIndex - 1),
                  icon: const Icon(Icons.arrow_back),
                ),
                Text(
                  '${_activeDifferenceIndex + 1} de ${activities.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  tooltip: 'Actividad siguiente',
                  onPressed: _activeDifferenceIndex >= activities.length - 1
                      ? null
                      : () => _moveComparisonPage(_activeDifferenceIndex + 1),
                  icon: const Icon(Icons.arrow_forward),
                ),
              ],
            ),
            SizedBox(
              height: 370,
              child: PageView.builder(
                controller: _comparisonPageController,
                itemCount: activities.length,
                onPageChanged: (index) =>
                    setState(() => _activeDifferenceIndex = index),
                itemBuilder: (context, index) {
                  final activity = activities[index];
                  final result = resultsById[activity.id];
                  return _DifferenceCard(
                    activity: activity,
                    result: result,
                    bestScores: bestScores,
                  );
                },
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${activities[_activeDifferenceIndex].title} · '
              '${_activeDifferenceIndex + 1} de ${activities.length}',
              style: const TextStyle(fontSize: 10, color: AppColors.grey),
            ),
            const SizedBox(height: 7),
            const Text(
              'Los mejores valores comparables se identifican con texto y color.',
              style: TextStyle(fontSize: 10, color: AppColors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  int? _bestScore(ActivityComparisonCriterion criterion) {
    final scores = _viewModel.results
        .map((result) => result.contributions[criterion]?.normalizedScore)
        .whereType<int>()
        .toList();
    if (scores.isEmpty) return null;
    return scores.reduce((left, right) => left > right ? left : right);
  }

  void _moveComparisonPage(int index) {
    setState(() => _activeDifferenceIndex = index);
    _comparisonPageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }
}

class _ActivityPickerSheet extends StatefulWidget {
  const _ActivityPickerSheet({
    required this.activities,
    required this.selectedIds,
  });

  final List<ActivityRecord> activities;
  final List<String> selectedIds;

  @override
  State<_ActivityPickerSheet> createState() => _ActivityPickerSheetState();
}

class _ActivityPickerSheetState extends State<_ActivityPickerSheet> {
  final _searchController = TextEditingController();
  late final Set<String> _draft = Set.of(widget.selectedIds);
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.activities
        .where((activity) {
          final query = _query.trim().toLowerCase();
          return query.isEmpty ||
              '${activity.title} ${activity.category} ${activity.locationName}'
                  .toLowerCase()
                  .contains(query);
        })
        .toList(growable: false);

    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Añadir actividades',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${_draft.length} de '
                        '${ActivityComparisonViewModel.maximumActivities} seleccionadas',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por actividad, categoría o lugar',
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay actividades que coincidan.',
                        style: TextStyle(color: AppColors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final activity = filtered[index];
                        final selected = _draft.contains(activity.id);
                        final canSelect =
                            _draft.length <
                                ActivityComparisonViewModel.maximumActivities ||
                            selected;
                        return CheckboxListTile(
                          value: selected,
                          onChanged: canSelect
                              ? (value) => setState(() {
                                  if (value == true) {
                                    _draft.add(activity.id);
                                  } else {
                                    _draft.remove(activity.id);
                                  }
                                })
                              : null,
                          title: Text(
                            activity.title,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            '${categoryLabel(activity.category)} · '
                            '${_durationLabel(activity)} · '
                            '${activity.price ?? 'Precio no informado'} · '
                            '${activity.locationName}',
                            style: const TextStyle(fontSize: 10),
                          ),
                          activeColor: AppColors.rosewood,
                          controlAffinity: ListTileControlAffinity.trailing,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 2,
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, _draft.toList(growable: false)),
                    child: const Text('Aplicar selección'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.icon,
    required this.message,
    required this.color,
    this.action,
  });

  final IconData icon;
  final String message;
  final Color color;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(icon, size: 17, color: AppColors.rosewood),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(fontSize: 11))),
        ?action,
      ],
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.color = AppColors.white});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE8F4FB)),
      boxShadow: [
        BoxShadow(
          color: AppColors.blue.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );
}

class _LoadingComparison extends StatelessWidget {
  const _LoadingComparison();

  @override
  Widget build(BuildContext context) => const _SectionCard(
    color: AppColors.white,
    child: Column(
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 12),
        Text(
          'Estamos comparando tus opciones',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 5),
        Text(
          'Revisamos las actividades y tus criterios.',
          style: TextStyle(fontSize: 11, color: AppColors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class _RankingCard extends StatelessWidget {
  const _RankingCard({
    required this.activity,
    required this.result,
    required this.position,
    required this.expanded,
    required this.onToggle,
  });

  final ActivityRecord activity;
  final ActivityComparisonResult result;
  final int position;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isWinner = position == 1;
    final leadingContributions =
        result.contributions.entries
            .where((entry) => entry.value.normalizedScore != null)
            .toList()
          ..sort(
            (left, right) => right.value.score.compareTo(left.value.score),
          );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWinner ? AppColors.rosewood : const Color(0xFFE8F4FB),
          width: isWinner ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isWinner)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 15, color: AppColors.rosewood),
                  SizedBox(width: 5),
                  Text(
                    'Mejor opción',
                    style: TextStyle(
                      color: AppColors.rosewood,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: isWinner
                    ? AppColors.yellow
                    : AppColors.blueLight,
                child: Text(
                  '$position',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryLabel(activity.category),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.grey,
                      ),
                    ),
                    Text(
                      activity.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                result.score.round().toString(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.rosewood,
                ),
              ),
              const Text('/100', style: TextStyle(fontSize: 10)),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (result.score / 100).clamp(0, 1),
              minHeight: 7,
              color: AppColors.rosewood,
              backgroundColor: AppColors.blueLight,
            ),
          ),
          if (leadingContributions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${leadingContributions.first.key.label}: '
              '${leadingContributions.first.value.displayValue ?? 'Sin dato'}',
              style: const TextStyle(fontSize: 10, color: AppColors.grey),
            ),
          ],
          TextButton(
            onPressed: onToggle,
            child: Text(expanded ? 'Ocultar factores' : 'Ver por qué'),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            for (final criterion in ActivityComparisonCriterion.values)
              _ContributionRow(
                criterion: criterion,
                contribution: result.contributions[criterion]!,
              ),
          ],
        ],
      ),
    );
  }
}

class _ContributionRow extends StatelessWidget {
  const _ContributionRow({required this.criterion, required this.contribution});

  final ActivityComparisonCriterion criterion;
  final ActivityComparisonContribution contribution;

  @override
  Widget build(BuildContext context) {
    final normalizedScore = contribution.normalizedScore;
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  criterion.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${contribution.score.toStringAsFixed(1)} pts · '
                '${contribution.weight}%',
                style: const TextStyle(fontSize: 10, color: AppColors.grey),
              ),
            ],
          ),
          if (normalizedScore != null)
            LinearProgressIndicator(
              value: normalizedScore / 100,
              minHeight: 4,
              color: AppColors.green,
              backgroundColor: AppColors.greenLight,
            )
          else
            const Text(
              'No suma puntos hasta contar con el dato necesario.',
              style: TextStyle(fontSize: 9, color: AppColors.grey),
            ),
          const SizedBox(height: 3),
          Text(
            contribution.explanation,
            style: const TextStyle(fontSize: 9, color: AppColors.grey),
          ),
        ],
      ),
    );
  }
}

class _DifferenceCard extends StatelessWidget {
  const _DifferenceCard({
    required this.activity,
    required this.result,
    required this.bestScores,
  });

  final ActivityRecord activity;
  final ActivityComparisonResult? result;
  final Map<ActivityComparisonCriterion, int?> bestScores;

  @override
  Widget build(BuildContext context) {
    final contributionMap =
        result?.contributions ??
        const <ActivityComparisonCriterion, ActivityComparisonContribution>{};
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8F4FB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            activity.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final criterion in ActivityComparisonCriterion.values)
            _DifferenceRow(
              criterion: criterion,
              contribution: contributionMap[criterion],
              isBest:
                  contributionMap[criterion]?.normalizedScore != null &&
                  contributionMap[criterion]?.normalizedScore ==
                      bestScores[criterion],
            ),
        ],
      ),
    );
  }
}

class _DifferenceRow extends StatelessWidget {
  const _DifferenceRow({
    required this.criterion,
    required this.contribution,
    required this.isBest,
  });

  final ActivityComparisonCriterion criterion;
  final ActivityComparisonContribution? contribution;
  final bool isBest;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isBest ? AppColors.greenLight : AppColors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                criterion.label,
                style: const TextStyle(fontSize: 10),
              ),
            ),
            Flexible(
              child: Text(
                contribution?.displayValue ?? 'No disponible',
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isBest)
              const Padding(
                padding: EdgeInsets.only(left: 5),
                child: Text(
                  'Mejor',
                  style: TextStyle(
                    fontSize: 8,
                    color: AppColors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Color _criterionColor(ActivityComparisonCriterion criterion) {
  switch (criterion) {
    case ActivityComparisonCriterion.duration:
      return AppColors.rosewood;
    case ActivityComparisonCriterion.category:
      return AppColors.blue;
    case ActivityComparisonCriterion.price:
      return AppColors.yellow;
    case ActivityComparisonCriterion.location:
      return AppColors.green;
    case ActivityComparisonCriterion.distance:
      return AppColors.blue.withValues(alpha: 0.65);
    case ActivityComparisonCriterion.capacity:
      return AppColors.rosewood.withValues(alpha: 0.5);
  }
}

String _durationLabel(ActivityRecord activity) {
  final start = DateTime.tryParse(activity.startTime);
  final end = DateTime.tryParse(activity.endTime);
  if (start == null || end == null || !end.isAfter(start)) {
    return 'Duración no disponible';
  }
  final minutes = end.difference(start).inMinutes;
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final remaining = minutes % 60;
  return remaining == 0 ? '$hours h' : '$hours h $remaining min';
}

String _locationIssueMessage(LocationIssue issue) {
  switch (issue) {
    case LocationIssue.serviceDisabled:
      return 'Activa el GPS para actualizar actividades cercanas.';
    case LocationIssue.permissionDenied:
    case LocationIssue.permissionDeniedForever:
      return 'Habilita el permiso de ubicación para actualizar actividades.';
    case LocationIssue.unavailable:
      return 'No hay una ubicación disponible; la distancia no se puntuará.';
  }
}
