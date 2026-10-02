import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/step_header.dart';
import 'step2_type_screen.dart';

class Step1InviteScreen extends StatefulWidget {
  const Step1InviteScreen({super.key});

  @override
  State<Step1InviteScreen> createState() => _Step1InviteScreenState();
}

class _Step1InviteScreenState extends State<Step1InviteScreen> {
  final List<String> friends = ['Alex', 'Sam', 'Jordan', 'Daniel Duplat', 'María Díaz'];
  final List<String> selected = ['Alex'];

  String initialsOf(String name) {
    final parts = name.split(' ');
    if (parts.length == 1) return parts[0][0];
    return parts[0][0] + parts[1][0];
  }

  void toggle(String name) {
    setState(() {
      if (selected.contains(name)) {
        selected.remove(name);
      } else {
        selected.add(name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StepHeader(title: 'Who are you inviting?', step: 1),
              const SizedBox(height: 14),
              Text('Selected (${selected.length})',
                  style: const TextStyle(fontSize: 12, color: AppColors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                children: selected.map((name) {
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
                              onTap: () => toggle(name),
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
              Expanded(
                child: ListView(
                  children: friends.map((name) {
                    final isActive = selected.contains(name);
                    return GestureDetector(
                      onTap: () => toggle(name),
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
                              onChanged: (_) => toggle(name),
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
                        onPressed: selected.isEmpty
                            ? null
                            : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Step2TypeScreen(friends: selected),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.rosewood,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Next (${selected.length})'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}