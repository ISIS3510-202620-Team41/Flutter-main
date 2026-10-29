import 'package:flutter/material.dart';
import 'dart:async';

import '../analytics/analytics_facade.dart';
import '../analytics/analytics_screen_catalog.dart';

import '../navigation/app_routes.dart';

import '../widgets/app_bottom_nav.dart';
import 'activities_screen.dart';
import 'friends_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import '../viewmodels/dashboard_view_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _viewModel = DashboardViewModel();

  void _onDestinationSelected(int index) {
    if (index == _viewModel.selectedIndex) return;

    _viewModel.selectTab(index);

    final screen = AnalyticsScreenCatalog.dashboardTabs[index];
    
    unawaited(
      AnalyticsFacade.instance.trackScreenView(
        screen: screen,
      ),
    );
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
        onOpenFlow: () => Navigator.pushNamed(context, AppRoutes.createActivity),
      ),
      const FriendsScreen(),
      ActivitiesScreen(
        onOpenDetail: () => Navigator.pushNamed(context, AppRoutes.activityDetail),
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
