import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/step_header.dart';
import 'step3_place_screen.dart';
import '../viewmodels/friends_view_model.dart';

class Step2TypeScreen extends StatefulWidget {
  final List<String> friends;
  const Step2TypeScreen({super.key, required this.friends});

  @override
  State<Step2TypeScreen> createState() => _Step2TypeScreenState();
}

class _Step2TypeScreenState extends State<Step2TypeScreen> {
  final _viewModel = ActivityCreationViewModel();
  final categories = const [
    {'name': 'Food', 'emoji': '🍽️'},
    {'name': 'Plays', 'emoji': '🎮'},
    {'name': 'Music', 'emoji': '🎵'},
    {'name': 'Study', 'emoji': '📚'},
    {'name': 'Sport', 'emoji': '⚽'},
    {'name': 'Cultural', 'emoji': '🎭'},
  ];

  void toggle(String name) {
    _viewModel.toggleCategory(name);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) => Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StepHeader(title: 'What type of activity?', step: 2),
              const SizedBox(height: 14),
              const Text('Selected one or more',
                  style: TextStyle(fontSize: 12, color: AppColors.grey)),
              const SizedBox(height: 10),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.45,
                  children: categories.map((cat) {
                    final isActive = _viewModel.selectedCategories.contains(cat['name']);
                    return GestureDetector(
                      onTap: () => toggle(cat['name']!),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.rosewood : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(color: Color(0x14000000), blurRadius: 6),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(cat['emoji']!, style: const TextStyle(fontSize: 26)),
                            const SizedBox(height: 8),
                            Text(
                              cat['name']!,
                              style: TextStyle(
                                fontSize: 12,
                                color: isActive ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.rosewood,
                        side: const BorderSide(color: AppColors.rosewood),
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Back'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _viewModel.selectedCategories.isEmpty
                            ? null
                            : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Step3PlaceScreen(
                                friends: widget.friends,
                                categories: _viewModel.selectedCategories,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.rosewood,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Next'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}