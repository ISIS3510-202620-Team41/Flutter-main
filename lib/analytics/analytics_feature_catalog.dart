import 'analytics_screen_catalog.dart';

class AnalyticsFeatureCatalog {
  // Features conocidas
  static const activityRecommendations = 'activity_recommendations';
  static const friendAvailability = 'friend_availability';
  static const activityJoining = 'activity_joining';

  // Acciones dentro de las features
  static const selectRecommendationAction = 'select_recommendation';
  static const viewAvailabilityAction = 'view_availability';
  static const joinRecommendedActivityAction ='join_recommended_activity';

  // Screens donde las features se cargan
  static const activityRecommendationsScreen =
      AnalyticsScreenCatalog.home;
  static const friendAvailabilityScreen =
      AnalyticsScreenCatalog.friendAvailability;
  static const activityJoiningScreen =
      AnalyticsScreenCatalog.home;
}