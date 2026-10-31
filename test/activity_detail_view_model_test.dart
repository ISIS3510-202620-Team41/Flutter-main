import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:llamalla/models/activity_record.dart';
import 'package:llamalla/services/activity_service.dart';
import 'package:llamalla/viewmodels/activity_view_models.dart';

class _FakeActivityService extends ActivityService {
  _FakeActivityService({
    required this.cachedActivity,
    required this.remoteActivity,
  });

  final ActivityRecord? cachedActivity;
  final Completer<ActivityRecord> remoteActivity;

  @override
  Future<ActivityRecord?> getCachedActivityById(String id) async {
    return cachedActivity;
  }

  @override
  Future<ActivityRecord> getActivityById(String id) {
    return remoteActivity.future;
  }
}

ActivityRecord _createActivity(String title) {
  return ActivityRecord(
    id: 'activity-1',
    title: title,
    description: 'Descripción de prueba',
    category: 'CULTURA',
    startTime: '2026-10-30T10:00:00',
    endTime: '2026-10-30T11:30:00',
    locationName: 'Universidad',
    latitude: 4.6097,
    longitude: -74.0817,
    participants: 5,
    capacity: 20,
    price: '10000',
    aboutLocation: 'Información del lugar',
    cachedAt: DateTime.utc(2026, 10, 30),
  );
}

void main() {
  group('ActivityDetailViewModel', () {
    test('shows cached activity before remote request finishes', () async {
      final remoteActivity = Completer<ActivityRecord>();

      final service = _FakeActivityService(
        cachedActivity: _createActivity('Actividad guardada'),
        remoteActivity: remoteActivity,
      );

      final viewModel = ActivityDetailViewModel(
        activityService: service,
      );

      final loading = viewModel.load('activity-1');

      await Future<void>.delayed(Duration.zero);

      expect(viewModel.activity?.title, 'Actividad guardada');
      expect(viewModel.isLoading, false);
      expect(viewModel.isRefreshing, true);

      remoteActivity.complete(
        _createActivity('Actividad actualizada'),
      );

      await loading;

      expect(viewModel.activity?.title, 'Actividad actualizada');
      expect(viewModel.isRefreshing, false);

      viewModel.dispose();
    });

    test('keeps cached activity when remote request fails', () async {
      final remoteActivity = Completer<ActivityRecord>();

      final service = _FakeActivityService(
        cachedActivity: _createActivity('Actividad guardada'),
        remoteActivity: remoteActivity,
      );

      final viewModel = ActivityDetailViewModel(
        activityService: service,
      );

      final loading = viewModel.load('activity-1');

      await Future<void>.delayed(Duration.zero);

      remoteActivity.completeError(
        const ActivityException('Backend unavailable'),
      );

      await loading;

      expect(viewModel.activity?.title, 'Actividad guardada');
      expect(viewModel.refreshErrorMessage, isNotNull);
      expect(viewModel.isLoading, false);

      viewModel.dispose();
    });
  });
}