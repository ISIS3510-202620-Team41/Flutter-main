import 'package:flutter/material.dart';
import '../models/activity.dart';
import '../theme/app_theme.dart';
import '../widgets/step_header.dart';
import 'step2_type_screen.dart';
import '../viewmodels/friends_view_model.dart';
import '../navigation/app_routes.dart';

class Step1InviteScreen extends StatefulWidget {
  const Step1InviteScreen({
    super.key,
    this.source,
    this.freeTimeMinutes,
  });

  final String? source;
  final int? freeTimeMinutes;

  @override
  State<Step1InviteScreen> createState() => _Step1InviteScreenState();
}

class _Step1InviteScreenState extends State<Step1InviteScreen> {

  late final ActivityCreationViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel =
        ActivityCreationViewModel(
          source: widget.source,
          freeTimeMinutes: widget.freeTimeMinutes,
        )..loadFriends();
  }
  String initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  void toggle(FriendStatus friend) {
    _viewModel.toggleFriend(friend);
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
              const StepHeader(title: '¿A quién quieres invitar?', step: 1),
              const SizedBox(height: 14),
              Text('Selecciona (${_viewModel.selectedAvailableFriends.length})',
                  style: const TextStyle(fontSize: 12, color: AppColors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                children: _viewModel.selectedAvailableFriends.map((friend) {
                  final name = friend.name;
                  return Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.blue,
                            child: Text(initialsOf(name),
                                style: const TextStyle(color: Colors.white)),
                          ),
                          Positioned(
                            right: -4,
                            top: -4,
                            child: GestureDetector(
                              onTap: () => toggle(friend),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE53935),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 10, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(name.split(' ')[0], style: const TextStyle(fontSize: 10)),
                    ],
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              if (_viewModel.isLoadingFriends)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_viewModel.friendsError != null)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _viewModel.friendsError!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: _viewModel.loadFriends,
                        child: const Text('Retry'),
                      ),
                    ],
                  )
              else if (_viewModel.availableFriends.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24, bottom: 12),
                    child: Center(
                      child: Text(
                        'No tienes amigos disponibles. Puedes continuar y crear una actividad para ti.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
              Expanded(
                child: ListView(
                  children: _viewModel.availableFriends.map((friend) {
                    final name = friend.name;
                    final isActive = _viewModel.isFriendSelected(friend);
                    return GestureDetector(
                      onTap: () => toggle(friend),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.blueLight : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive ? AppColors.blue : const Color(0xFFEDEFF1),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor:
                              isActive ? AppColors.blue : const Color(0xFFCDEBF8),
                              child: Text(initialsOf(name),
                                  style: const TextStyle(color: Colors.white, fontSize: 13)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: const TextStyle(
                                          fontSize: 14, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  const Row(
                                    children: [
                                      Icon(Icons.circle, size: 7, color: AppColors.green),
                                      SizedBox(width: 5),
                                      Text('Free',
                                          style: TextStyle(fontSize: 11, color: AppColors.green)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Checkbox(
                              value: isActive,
                              onChanged: (_) => toggle(friend),
                              activeColor: AppColors.blue,
                              side: const BorderSide(color: Color(0xFFD0D5DA)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4)),
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
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _viewModel.isLoadingFriends
                            ? null
                            : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              settings: const RouteSettings(
                                name: AppRoutes.activityType,
                              ),
                              builder: (_) => Step2TypeScreen(
                                viewModel: _viewModel,
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
                        child: Text(
                          _viewModel.selectedAvailableFriends.isEmpty
                              ? 'Continuar sin amigos'
                              : 'Next (${_viewModel.selectedAvailableFriends.length})',
                        ),
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