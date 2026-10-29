import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:llamalla/analytics/analytics_facade.dart';
import 'package:llamalla/viewmodels/dashboard_view_model.dart';

class RecordingAnalyticsFacade extends AnalyticsFacade {
  RecordingAnalyticsFacade()
      : super(
          client: MockClient(
            (_) async => http.Response('', 200),
          ),
        );

  final List<String> screenViews = [];

  @override
  Future<void> trackScreenView({
    required String screen,
  }) async {
    screenViews.add(screen);
  }
}

void main() {
  group('DashboardViewModel analytics', () {
    late RecordingAnalyticsFacade analytics;
    late DashboardViewModel viewModel;

    setUp(() {
      analytics = RecordingAnalyticsFacade();

      viewModel = DashboardViewModel(
        analyticsFacade: analytics,
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('tracks a screen when the selected tab changes', () {
      viewModel.selectTab(1);

      expect(viewModel.selectedIndex, 1);
      expect(
        analytics.screenViews,
        ['FriendAvailability'],
      );
    });

    test('does not track the same tab twice', () {
      viewModel.selectTab(1);
      viewModel.selectTab(1);

      expect(viewModel.selectedIndex, 1);
      expect(
        analytics.screenViews,
        ['FriendAvailability'],
      );
    });

    test('tracks each distinct tab selection', () {
      viewModel.selectTab(1);
      viewModel.selectTab(2);
      viewModel.selectTab(3);

      expect(
        analytics.screenViews,
        [
          'FriendAvailability',
          'Activities',
          'Profile',
        ],
      );
    });

    test('does not track invalid tab indices', () {
      viewModel.selectTab(-1);
      viewModel.selectTab(4);

      expect(viewModel.selectedIndex, 0);
      expect(analytics.screenViews, isEmpty);
    });

    test('does not track the initial tab when selected again', () {
      viewModel.selectTab(0);

      expect(viewModel.selectedIndex, 0);
      expect(analytics.screenViews, isEmpty);
    });
  });
}