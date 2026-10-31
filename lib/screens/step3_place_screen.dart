import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/step_header.dart';
import 'activity_created_screen.dart';
import '../viewmodels/friends_view_model.dart';
import '../navigation/app_routes.dart';
import '../models/activity_draft.dart';

class Step3PlaceScreen extends StatefulWidget {
  const Step3PlaceScreen({super.key, required this.viewModel});

  final ActivityCreationViewModel viewModel;

  @override
  State<Step3PlaceScreen> createState() => _Step3PlaceScreenState();
}

class _Step3PlaceScreenState extends State<Step3PlaceScreen> {
  ActivityCreationViewModel get _viewModel => widget.viewModel;

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

  Future<void> confirm() async {
    final ok = await _viewModel.submit();
    if (!ok || !mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: AppRoutes.activityCreated),
        builder: (_) => ActivityCreatedScreen(
          activity: _viewModel.createdActivity!,
          friends: List<String>.from(_viewModel.selectedFriends),
          savedOffline: _viewModel.savedOffline,
        ),
      ),
          (route) => route.isFirst,
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
                    children: availablePlaces.map((place) {
                      final isActive =
                          _viewModel.selectedPlace?.name == place.name;
                      return GestureDetector(
                        onTap: () => _viewModel.selectPlace(place),
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
                                      place.name,
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
                                          place.distance,
                                          AppColors.rosewood,
                                        ),
                                        infoItem(
                                          Icons.timer_outlined,
                                          place.durationLabel,
                                          AppColors.grey,
                                        ),
                                        infoItem(
                                          Icons.savings_outlined,
                                          place.price,
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
                if (_viewModel.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      _viewModel.errorMessage!,
                      style: const TextStyle(fontSize: 12, color: AppColors.rosewood),
                    ),
                  ),
                if (_viewModel.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      _viewModel.errorMessage!,
                      style: const TextStyle(fontSize: 12, color: AppColors.rosewood),
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
                          onPressed: (_viewModel.canSubmit && !_viewModel.isSubmitting) ? confirm : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.rosewood,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _viewModel.isSubmitting
                              ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                              : const Text('Confirmar'),
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
