import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/step_header.dart';
import 'activity_created_screen.dart';
import '../viewmodels/friends_view_model.dart';

class Step3PlaceScreen extends StatefulWidget {
  final List<String> friends;
  final List<String> categories;
  const Step3PlaceScreen({
    super.key,
    required this.friends,
    required this.categories,
  });

  @override
  State<Step3PlaceScreen> createState() => _Step3PlaceScreenState();
}

class _Step3PlaceScreenState extends State<Step3PlaceScreen> {
  // Test places, later they come from the database
  final List<Map<String, String>> places = [
    {
      'name': 'Bistro',
      'distance': '500 m',
      'duration': '2 h',
      'price': '\$30K',
    },
    {
      'name': 'Pizza Hut',
      'distance': '0.7 km',
      'duration': '1.5 h',
      'price': '\$20K',
    },
  ];

  final _viewModel = ActivityCreationViewModel();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Widget infoItem(IconData icon, String text, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 3),
          Text(
            text,
            style: const TextStyle(fontSize: 11, color: AppColors.grey),
          ),
        ],
      ),
    );
  }

  void confirm() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ActivityCreatedScreen()),
      (route) => route.isFirst, // deja solo el Dashboard debajo
    );
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
                const StepHeader(title: 'Which place?', step: 3),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search the place',
                          hintStyle: const TextStyle(
                            color: AppColors.grey,
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            size: 18,
                            color: AppColors.grey,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFEDEFF1),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFEDEFF1),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEDEFF1)),
                      ),
                      child: const Icon(
                        Icons.filter_list,
                        size: 20,
                        color: AppColors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView(
                    children: places.map((place) {
                      final isActive =
                          _viewModel.selectedPlace == place['name'];
                      return GestureDetector(
                        onTap: () => _viewModel.selectPlace(place['name']!),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.blueLight
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isActive
                                  ? AppColors.blue
                                  : const Color(0xFFEDEFF1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.blue,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Center(
                                  child: Text(
                                    '🍽️',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      place['name']!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        infoItem(
                                          Icons.location_on,
                                          place['distance']!,
                                          AppColors.rosewood,
                                        ),
                                        infoItem(
                                          Icons.timer_outlined,
                                          place['duration']!,
                                          AppColors.grey,
                                        ),
                                        infoItem(
                                          Icons.savings_outlined,
                                          place['price']!,
                                          const Color(0xFFE0A93B),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                isActive
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                color: isActive
                                    ? AppColors.blue
                                    : const Color(0xFFD0D5DA),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 26,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Atrás'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: confirm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.rosewood,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Confirmar'),
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
