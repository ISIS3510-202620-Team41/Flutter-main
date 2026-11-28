
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/joined_activity_record.dart';
import '../database/local_database_facade.dart';
import '../services/auth_service.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _payloadPrefix = 'llamalla_plan:';

  bool _initialized = false;
  bool _exactAlarmsAllowed = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    final timezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezone.identifier));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(settings: settings);

    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    await initialize();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    bool notificationsAllowed = true;

    if (android != null) {
      notificationsAllowed =
          await android.requestNotificationsPermission() ?? false;

      _exactAlarmsAllowed =
          await android.requestExactAlarmsPermission() ?? false;
    }

    if (ios != null) {
      notificationsAllowed =
          await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ?? false;
    }

    return notificationsAllowed;
  }

  Future<void> syncCurrentUserPlans() async {
    await initialize();

    final userId = await AuthService().getCurrentUserId();
    if (userId == null || userId.isEmpty) return;

    final repository = LocalDatabaseFacade.instance.joinedActivities;
    if (repository == null) return;

    final plans = await repository.getForUser(userId);

    await syncPlans(plans);
  }

  Future<void> syncPlans(
    List<JoinedActivityRecord> plans,
  ) async {
    await initialize();

    final preferences = await SharedPreferences.getInstance();

    // Cancelamos solamente las notificaciones de actividades de Llamalla.
    final pending = await _plugin.pendingNotificationRequests();

    for (final notification in pending) {
      if (notification.payload?.startsWith(_payloadPrefix) ?? false) {
        await _plugin.cancel(id: notification.id);
      }
    }

    final enabled =
        preferences.getBool('activity_reminders_enabled') ?? true;

    if (!enabled) return;

    final reminderOptions = <({int minutes, bool enabled})>[
      (
        minutes: 1440,
        enabled: preferences.getBool('reminder_one_day') ?? true,
      ),
      (
        minutes: 60,
        enabled: preferences.getBool('reminder_one_hour') ?? true,
      ),
      (
        minutes: 15,
        enabled: preferences.getBool('reminder_fifteen_minutes') ?? false,
      ),
    ];

    final now = DateTime.now();

    for (final enrollment in plans) {
      if (enrollment.isPendingLeave) continue;

      final activity = enrollment.activity;
      final parsedStart = DateTime.tryParse(activity.startTime);

      if (parsedStart == null) continue;

      final start = parsedStart.toLocal();

      for (final option in reminderOptions) {
        if (!option.enabled) continue;

        final reminderDate = start.subtract(
          Duration(minutes: option.minutes),
        );

        // No programamos avisos que ya pasaron.
        if (!reminderDate.isAfter(now)) continue;

        final notificationId = _notificationId(
          activity.id,
          option.minutes,
        );

        await _plugin.zonedSchedule(
          id: notificationId,
          title: '¡Tu actividad se acerca!',
          body: '${activity.title} comienza en ${_formatLeadTime(option.minutes)}.',
          scheduledDate: tz.TZDateTime.from(
            reminderDate,
            tz.local,
          ),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'llamalla_plan_reminders',
              'Recordatorios de actividades',
              channelDescription:
                  'Avisos antes del inicio de tus actividades.',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: _exactAlarmsAllowed
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          payload: '$_payloadPrefix${activity.id}',
        );
      }
    }
  }

  int _notificationId(String activityId, int minutes) {
    // Hash estable entre ejecuciones de la aplicación.
    var hash = 0x811c9dc5;

    for (final unit in activityId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }

    hash = (hash + minutes) & 0x7fffffff;
    return hash == 0 ? 1 : hash;
  }

  String _formatLeadTime(int minutes) {
    if (minutes == 1440) return '24 horas';
    if (minutes == 60) return '1 hora';
    return '$minutes minutos';
  }
}