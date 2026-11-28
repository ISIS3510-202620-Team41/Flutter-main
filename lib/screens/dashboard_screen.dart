import 'package:flutter/material.dart';

import '../analytics/analytics_navigator_observer.dart';
import '../navigation/app_routes.dart';

import '../widgets/app_bottom_nav.dart';
import 'activities_screen.dart';
import 'friends_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import '../viewmodels/dashboard_view_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.routeObserver,
  });

  final AnalyticsNavigatorObserver routeObserver;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _viewModel = DashboardViewModel();

  void _onDestinationSelected(int index) {
    _viewModel.selectTab(index);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      HomeScreen(
        routeObserver: widget.routeObserver,
        isActive: _viewModel.selectedIndex == 0,
        onOpenFlow: (freeTimeMinutes) {
          Navigator.pushNamed(
            context,
            AppRoutes.createActivity,
            arguments: {'freeTimeMinutes': freeTimeMinutes},
          );
        },
      ),
      const FriendsScreen(),
      ActivitiesScreen(
        onOpenDetail: (activityId) => Navigator.pushNamed(context, AppRoutes.activityDetail, arguments: activityId),
      ),
      const ProfileScreen(),
    ];

    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) => Scaffold(
        body: IndexedStack(index: _viewModel.selectedIndex, children: screens),
        bottomNavigationBar: AppBottomNav(
          index: _viewModel.selectedIndex,
          onDestinationSelected: _onDestinationSelected,
        ),
      ),
    );
  }
}
