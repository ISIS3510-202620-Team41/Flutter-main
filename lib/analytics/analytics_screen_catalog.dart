import '../navigation/app_routes.dart';

class AnalyticsScreenCatalog {
  //Si se desea cambiar el nombre de una pantalla debe hacerce aca y en el analytics-engine

  // Dashboard
  static const home = 'Home';
  static const friendAvailability = 'FriendAvailability';
  static const activities = 'Activities';
  static const profile = 'Profile';

  // Authentication
  static const login = 'Login';
  static const register = 'Register';

  // Flow Activity
  static const activityCreate = 'ActivityCreate';
  static const activityType = 'ActivityType';
  static const activityPlace = 'ActivityPlace';
  static const activityCreated = 'ActivityCreated';
  static const activityDetail = 'ActivityDetail';

  static const List<String> dashboardTabs = [
    home,
    friendAvailability,
    activities,
    profile,
  ];

  static const Map<String, String> _routeToScreen = {
    AppRoutes.home: home,
    AppRoutes.login: login,
    AppRoutes.register: register,
    AppRoutes.createActivity: activityCreate,
    AppRoutes.activityType: activityType,
    AppRoutes.activityPlace: activityPlace,
    AppRoutes.activityCreated: activityCreated,
    AppRoutes.activityDetail: activityDetail,
  };

  static String? screenForRoute(String? routeName) {
    if (routeName == null) return null;

    return _routeToScreen[routeName];
  }
}