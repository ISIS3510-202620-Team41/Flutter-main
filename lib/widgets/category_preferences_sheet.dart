import 'package:flutter/material.dart';

import '../models/activity_draft.dart';
import '../theme/app_theme.dart';
import '../viewmodels/category_preferences_view_model.dart';

Future<void> showCategoryPreferencesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _CategoryPreferencesSheet(),
  );
}

class _CategoryPreferencesSheet extends StatefulWidget {
  const _CategoryPreferencesSheet();

  @override
  State<_CategoryPreferencesSheet> createState() =>
      _CategoryPreferencesSheetState();
}

class _CategoryPreferencesSheetState extends State<_CategoryPreferencesSheet> {
  late final _viewModel = CategoryPreferencesViewModel()..load();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mis categorías favoritas',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Se guardan en tu dispositivo y funcionan sin conexión.',
              style: TextStyle(fontSize: 11, color: AppColors.grey),
            ),
            const SizedBox(height: 12),
            if (_viewModel.isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categoryOptions
                    .map(
                      (option) => FilterChip(
                    label: Text('${option.emoji} ${option.label}'),
                    selected: _viewModel.isSelected(option.backendValue),
                    onSelected: (_) =>
                        _viewModel.toggle(option.backendValue),
                  ),
                )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}