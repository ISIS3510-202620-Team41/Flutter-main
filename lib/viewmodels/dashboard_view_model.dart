import 'dart:async';

import 'package:flutter/foundation.dart';

import '../analytics/analytics_facade.dart';
import '../analytics/analytics_screen_catalog.dart';
import '../analytics/analytics_feature_catalog.dart';

class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel({
    AnalyticsFacade? analyticsFacade,
  }) : _analyticsFacade =
           analyticsFacade ?? AnalyticsFacade.instance;

  final AnalyticsFacade _analyticsFacade;

  int _selectedIndex = 0;

  int get selectedIndex => _selectedIndex;

  void selectTab(int index) {
    if (index < 0 ||
        index >= AnalyticsScreenCatalog.dashboardTabs.length) {
      return;
    }

    if (_selectedIndex == index) return;

    _selectedIndex = index;

    final screen = AnalyticsScreenCatalog.dashboardTabs[index];

    notifyListeners();

    unawaited(
      _analyticsFacade.trackScreenView(
        screen: screen,
      ),
    );

    if (screen == AnalyticsFeatureCatalog.friendAvailabilityScreen) {
        unawaited(
          _analyticsFacade.trackFeatureUsed(
            feature: AnalyticsFeatureCatalog.friendAvailability,
            action: AnalyticsFeatureCatalog.viewAvailabilityAction,
            screen: AnalyticsFeatureCatalog.friendAvailabilityScreen,
        ),
      );
    }
  }
}