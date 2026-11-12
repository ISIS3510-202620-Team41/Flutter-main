import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../navigation/app_routes.dart';
import '../theme/app_theme.dart';
import '../viewmodels/friends_view_model.dart';
import '../widgets/header.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _viewModel = FriendsViewModel();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel.load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  /// Abre el flujo de crear actividad marcando que viene de Friend Availability.
  /// El backend usa ese 'source' para emitir plan_created.
  void _organizeActivity() {
    Navigator.pushNamed(
      context,
      AppRoutes.createActivity,
      arguments: const {'source': 'friend_availability'},
    );
  }

  /// Pide un correo y envía una solicitud de amistad.
  Future<void> _askEmailAndSendRequest() async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar solicitud de amistad'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'correo@ejemplo.com'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (email == null || email.trim().isEmpty || !mounted) return;

    final error = await _viewModel.sendRequest(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Solicitud enviada')),
    );
  }

  /// Contenido de la lista según el estado: cargando, error, vacío o amigos.
  Widget _buildFriendsList() {
    if (_viewModel.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_viewModel.errorMessage != null) {
      return Center(
        child: Column(
          children: [
            Text(
              _viewModel.errorMessage!,
              style: const TextStyle(fontSize: 12),
            ),
            TextButton(
              onPressed: _viewModel.load,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final friends = _viewModel.visibleFriends;

    if (friends.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Ningún amigo disponible ahora.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      );
    }

    return Column(
      children: friends
          .map(
            (friend) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _FriendTile(
            friend: friend,
            onInvite: _organizeActivity,
          ),
        ),
      )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Header(showAdd: true),
              const SizedBox(height: 24),
              const Text(
                'Amigos disponibles',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _viewModel.setQuery,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search, size: 18),
                        hintText: 'Buscar por nombre',
                        hintStyle: TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Sin backend para filtros todavía: se deja deshabilitado.
                  const IconButton.filledTonal(
                    onPressed: null,
                    icon: Icon(Icons.tune, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _organizeActivity,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    foregroundColor: AppColors.black,
                    minimumSize: const Size.fromHeight(38),
                  ),
                  icon: const Icon(Icons.add_circle_outline, size: 17),
                  label: const Text(
                    'Organizar actividad',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildFriendsList(),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _askEmailAndSendRequest,
                  child: const Text(
                    'Buscar otras personas',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
              Center(
                child: OutlinedButton(
                  onPressed: _askEmailAndSendRequest,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.rosewood,
                    side: const BorderSide(color: AppColors.rosewood),
                  ),
                  child: const Text(
                    'Conectar con otros',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend, required this.onInvite});

  final FriendStatus friend;
  final VoidCallback onInvite;

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
            child: Text(
              friend.initials,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  friend.status,
                  style: TextStyle(
                    fontSize: 10,
                    color: friend.statusInMinutes
                        ? AppColors.black
                        : AppColors.green,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onInvite,
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