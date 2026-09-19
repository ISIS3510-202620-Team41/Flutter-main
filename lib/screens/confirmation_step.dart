import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ConfirmationStepView extends StatelessWidget {
  const ConfirmationStepView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _buildSuccessCheck(),
                    const SizedBox(height: 20),
                    _buildActivityCard(),
                    const SizedBox(height: 20),
                    _buildLocationSection(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            _buildBottomActions(context),
          ],
        ),
      ),
    );
  }
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.black),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 4),
          const Text(
            'Actividad creada',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.black,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildSuccessCheck() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check, color: AppColors.green, size: 34),
    );
  }
  Widget _buildActivityCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActivityImage(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AMIGOS CONFIRMADOS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black.withValues(alpha: 0.55),
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 10),
                _buildConfirmedFriends(),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildActivityImage() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SizedBox(
        height: 150,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3B2F2A), Color(0xFF6B4F3F)],
                ),
              ),
            ),
            Center(
              child: Icon(
                Icons.storefront,
                size: 48,
                color: AppColors.white.withValues(alpha: 0.25),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppColors.black.withValues(alpha: 0.65)],
                ),
              ),
            ),
            Positioned(
              left: 14,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bistro',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '500 m · 2h estimados',
                    style: TextStyle(
                      color: AppColors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildConfirmedFriends() {
    final friends = [
      _Friend('L', AppColors.blue),
      _Friend('R', AppColors.yellow),
      _Friend('B', AppColors.rosewood),
      _Friend('T', AppColors.green),
    ];

    return Row(
      children: [
        SizedBox(
          height: 32,
          child: Stack(
            children: List.generate(friends.length, (i) {
              return Positioned(
                left: i * 22.0,
                child: _AvatarBubble(friend: friends[i]),
              );
            }),
          ),
        ),
        SizedBox(width: friends.length * 22.0 + 4),
        Expanded(
          child: Text(
            'Lucía, Rini, Ben, Tú',
            style: TextStyle(fontSize: 13, color: AppColors.black),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ubicación',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.black,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 140,
            width: double.infinity,
            child: Stack(
              children: [
                Container(color: AppColors.blue.withValues(alpha: 0.25)),
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 60,
                  child: Container(width: 3, color: AppColors.white),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 55,
                  child: Container(height: 3, color: AppColors.white),
                ),
                Positioned(
                  left: 45,
                  top: 40,
                  child: Column(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.rosewood, size: 30),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Bistro', style: TextStyle(fontSize: 10, color: AppColors.black)),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 30,
                  bottom: 20,
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.yellow,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.white, width: 2),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(color: AppColors.black.withValues(alpha: 0.1), blurRadius: 3),
                          ],
                        ),
                        child: const Text(
                          'Campus universitario',
                          style: TextStyle(fontSize: 9, color: AppColors.black),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildBottomActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.edit, size: 18, color: AppColors.rosewood),
            label: const Text('Editar', style: TextStyle(color: AppColors.rosewood)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.rosewood),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.map, size: 18, color: AppColors.white),
              label: const Text('Ver ruta', style: TextStyle(color: AppColors.white)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.rosewood,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.yellow,
              borderRadius: BorderRadius.circular(30),
            ),
            child: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.share, color: AppColors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _Friend {
  final String initial;
  final Color color;
  _Friend(this.initial, this.color);
}

class _AvatarBubble extends StatelessWidget {
  final _Friend friend;
  const _AvatarBubble({required this.friend});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: friend.color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        friend.initial,
        style: const TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}