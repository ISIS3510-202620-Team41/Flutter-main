import 'package:flutter_test/flutter_test.dart';
import 'package:llamalla/models/profile_models.dart';
import 'package:llamalla/services/profile_service.dart';
import 'package:llamalla/services/schedule_service.dart';
import 'package:llamalla/viewmodels/home_view_model.dart';

class _ProfileService extends ProfileService {
  @override
  Future<UserProfile> getCurrentUser() async => const UserProfile(
    id: '1',
    email: 'juan@test.com',
    name: 'Juan Pérez',
    bio: '',
  );
}

class _ScheduleService extends ScheduleService {
  @override
  Future<DayGaps> getGaps({
    required DateTime date,
    String timezone = 'America/Bogota',
  }) async {
    return DayGaps(
      date: date,
      timezone: timezone,
      free: [
        FreeInterval(
          start: DateTime(2026, 10, 3, 11, 30),
          end: DateTime(2026, 10, 3, 13),
        ),
      ],
    );
  }
}

void main() {
  test('loads profile name and derives the next free interval', () async {
    final viewModel = HomeViewModel(
      profileService: _ProfileService(),
      scheduleService: _ScheduleService(),
      now: () => DateTime(2026, 10, 3, 9),
    );

    await viewModel.load();

    expect(viewModel.greetingName, 'Juan');
    expect(viewModel.freeMinutes, 90);
    expect(formatClockTime(viewModel.nextFreeInterval!.start), '11:30 AM');
    expect(viewModel.errorMessage, isNull);
    viewModel.dispose();
  });
}
