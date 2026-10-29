import 'package:flutter_test/flutter_test.dart';
import 'package:llamalla/analytics/analytics_screen_catalog.dart';
import 'package:llamalla/navigation/app_routes.dart';

void main() {
  test('activity routes map to distinct screen names', () {
    expect(
      AnalyticsScreenCatalog.screenForRoute(
        AppRoutes.createActivity,
      ),
      AnalyticsScreenCatalog.activityCreate,
    );

    expect(
      AnalyticsScreenCatalog.screenForRoute(
        AppRoutes.activityCreated,
      ),
      AnalyticsScreenCatalog.activityCreated,
    );

    expect(
      AnalyticsScreenCatalog.screenForRoute(
        AppRoutes.activityDetail,
      ),
      AnalyticsScreenCatalog.activityDetail,
    );

    expect(
      AnalyticsScreenCatalog.screenForRoute(
        AppRoutes.createActivity,
      ),
      isNot(
        AnalyticsScreenCatalog.screenForRoute(
          AppRoutes.activityCreated,
        ),
      ),
    );
  });

  test('activity creation steps have distinct screen names', () {
    expect(
      AnalyticsScreenCatalog.screenForRoute(
        AppRoutes.activityType,
      ),
      AnalyticsScreenCatalog.activityType,
    );

    expect(
      AnalyticsScreenCatalog.screenForRoute(
        AppRoutes.activityPlace,
      ),
      AnalyticsScreenCatalog.activityPlace,
    );
  });

  test('unknown and unnamed routes are not classified as Home', () {
    expect(
      AnalyticsScreenCatalog.screenForRoute(null),
      isNull,
    );

    expect(
      AnalyticsScreenCatalog.screenForRoute('/unknown'),
      isNull,
    );
  });

  test('dashboard tabs use a central and consistent catalog', () {
    expect(
      AnalyticsScreenCatalog.dashboardTabs,
      [
        AnalyticsScreenCatalog.home,
        AnalyticsScreenCatalog.friendAvailability,
        AnalyticsScreenCatalog.activities,
        AnalyticsScreenCatalog.profile,
      ],
    );
  });
}