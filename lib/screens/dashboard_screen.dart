import 'package:flutter/material.dart';
import 'dart:async';

import '../services/analytics_service.dart';
import '../widgets/app_bottom_nav.dart';
import 'activities_screen.dart';
import 'friends_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _index = 0;

  void _onDestinationSelected(int index) {
    setState(() => _index = index);
    const screens = ['Home', 'FriendAvailability', 'Activities', 'Profile'];
    unawaited(
      AnalyticsService.instance.track('screen_view', {
        'screen': screens[index],
      }),
    );
    AnalyticsService.instance.setCurrentScreen(screens[index]);
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      HomeScreen(
        onOpenFlow: () => Navigator.pushNamed(context, '/activity/create'),
      ),
      const FriendsScreen(),
      ActivitiesScreen(
        onOpenDetail: () => Navigator.pushNamed(context, '/activity-detail'),
      ),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: AppBottomNav(
        index: _index,
        onDestinationSelected: _onDestinationSelected,
      ),
    );
  }
}
