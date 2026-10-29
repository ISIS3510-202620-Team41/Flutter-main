import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:llamalla/analytics/analytics_navigator_observer.dart';
import 'package:llamalla/analytics/analytics_screen_catalog.dart';
import 'package:llamalla/navigation/app_routes.dart';

void main() {
  group('AnalyticsNavigatorObserver', () {
    test('uses the initial screen resolver for the home route', () {
      final trackedScreens = <String>[];

      final observer = AnalyticsNavigatorObserver(
        initialScreenResolver: () => AnalyticsScreenCatalog.login,
        onScreenView: (screen) {
          trackedScreens.add(screen);
          return Future<void>.value();
        },
        currentDashboardTabResolver: () =>
            AnalyticsScreenCatalog.home,
      );

      final homeRoute = _route(AppRoutes.home);

      observer.didPush(homeRoute, null);

      expect(
        trackedScreens,
        [AnalyticsScreenCatalog.login],
      );
    });

    test('tracks a recognized route', () {
      final trackedScreens = <String>[];

      final observer = AnalyticsNavigatorObserver(
        initialScreenResolver: () => AnalyticsScreenCatalog.home,
        onScreenView: (screen) {
          trackedScreens.add(screen);
          return Future<void>.value();
        },
        currentDashboardTabResolver: () =>
            AnalyticsScreenCatalog.home,
      );

      final detailRoute = _route(AppRoutes.activityDetail);

      observer.didPush(detailRoute, null);

      expect(
        trackedScreens,
        [AnalyticsScreenCatalog.activityDetail],
      );
    });

    test('tracks the visible dashboard tab when returning from detail', () {
      final trackedScreens = <String>[];

      final observer = AnalyticsNavigatorObserver(
        initialScreenResolver: () => AnalyticsScreenCatalog.home,
        onScreenView: (screen) {
          trackedScreens.add(screen);
          return Future<void>.value();
        },
        currentDashboardTabResolver: () =>
            AnalyticsScreenCatalog.friendAvailability,
      );

      final homeRoute = _route(AppRoutes.home);
      final detailRoute = _route(AppRoutes.activityDetail);

      observer.didPush(homeRoute, null);
      observer.didPush(detailRoute, homeRoute);
      observer.didPop(detailRoute, homeRoute);

      expect(
        trackedScreens,
        [
          AnalyticsScreenCatalog.home,
          AnalyticsScreenCatalog.activityDetail,
          AnalyticsScreenCatalog.friendAvailability,
        ],
      );
    });

    test('ignores routes absent from the screen catalog', () {
      final trackedScreens = <String>[];

      final observer = AnalyticsNavigatorObserver(
        initialScreenResolver: () => AnalyticsScreenCatalog.home,
        onScreenView: (screen) {
          trackedScreens.add(screen);
          return Future<void>.value();
        },
        currentDashboardTabResolver: () =>
            AnalyticsScreenCatalog.home,
      );

      observer.didPush(_route('/unknown'), null);

      expect(trackedScreens, isEmpty);
    });
  });
}

MaterialPageRoute<void> _route(String name) {
  return MaterialPageRoute<void>(
    settings: RouteSettings(name: name),
    builder: (_) => const SizedBox.shrink(),
  );
}