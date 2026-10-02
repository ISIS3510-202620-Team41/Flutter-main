import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models/activity.dart';
import '../theme/app_theme.dart';
import '../widgets/header.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Header(showAdd: true),
            const SizedBox(height: 24),
            const Text('Amigos disponibles', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search, size: 18),
                      hintText: 'Buscar por nombre',
                      hintStyle: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () {},
                  icon: const Icon(Icons.tune, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {},
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: AppColors.black,
                  minimumSize: const Size.fromHeight(38),
                ),
                icon: const Icon(Icons.add_circle_outline, size: 17),
                label: const Text('Organizar actividad', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(height: 14),
            ...friends.map((friend) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _FriendTile(friend: friend),
                )),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () {},
                child: const Text('Buscar otras personas', style: TextStyle(fontSize: 11)),
              ),
            ),
            Center(
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.rosewood,
                  side: const BorderSide(color: AppColors.rosewood),
                ),
                child: const Text('Conectar con otros', style: TextStyle(fontSize: 11)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend});

  final FriendStatus friend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: friend.statusInMinutes
                ? AppColors.yellow.withValues(alpha: 0.80)
                : AppColors.green.withValues(alpha: 0.85),
            child: Text(friend.initials, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friend.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  friend.status,
                  style: TextStyle(
                    fontSize: 10,
                    color: friend.statusInMinutes ? AppColors.black : AppColors.green,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            style: IconButton.styleFrom(
              backgroundColor: AppColors.blue.withValues(alpha: 0.28),
            ),
            icon: const Icon(Icons.person_add_alt_1, size: 16),
          ),
        ],
      ),
    );
  }
}
