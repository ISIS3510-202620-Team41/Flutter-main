
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class ActivityRemindersScreen extends StatefulWidget {
  const ActivityRemindersScreen({super.key});

  @override
  State<ActivityRemindersScreen> createState() =>
      _ActivityRemindersScreenState();
}

class _ActivityRemindersScreenState
    extends State<ActivityRemindersScreen> {
  bool _isLoading = true;
  bool _enabled = true;
  bool _oneDayBefore = true;
  bool _oneHourBefore = true;
  bool _fifteenMinutesBefore = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final preferences = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _enabled =
          preferences.getBool('activity_reminders_enabled') ?? true;
      _oneDayBefore =
          preferences.getBool('reminder_one_day') ?? true;
      _oneHourBefore =
          preferences.getBool('reminder_one_hour') ?? true;
      _fifteenMinutesBefore =
          preferences.getBool('reminder_fifteen_minutes') ?? false;

      _isLoading = false;
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(key, value);
  }

  Future<void> _changePreference({
    required String key,
    required bool value,
    required VoidCallback updateState,
  }) async {
    setState(updateState);

    try {
      await _savePreference(key, value);
      await NotificationService.instance.syncCurrentUserPlans();
    } catch (_) {
      if (!mounted) return;
      await _loadPreferences();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar la preferencia.'),
        ),
      );
    }
  }

  Widget _reminderOption({
    required String title,
    required String subtitle,
    required bool value,
    required String keyName,
    required VoidCallback updateState,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: _enabled
          ? (newValue) => _changePreference(
                key: keyName,
                value: newValue,
                updateState: updateState,
              )
          : null,
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.grey, fontSize: 12),
      ),
      activeThumbColor: AppColors.black,
      activeTrackColor: AppColors.blue,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text(
          'Recordatorios',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.blueLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.notifications_active_outlined,
                          size: 30, color: AppColors.black),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Configura cuándo quieres recordar '
                          'tus próximas actividades.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Card(
                  child: SwitchListTile(
                    value: _enabled,
                    onChanged: (value) => _changePreference(
                      key: 'activity_reminders_enabled',
                      value: value,
                      updateState: () => _enabled = value,
                    ),
                    title: const Text(
                      'Activar recordatorios',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Permitir recordatorios de tus actividades',
                    ),
                    activeThumbColor: AppColors.black,
                    activeTrackColor: AppColors.blue,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final granted =
                        await NotificationService.instance.requestPermissions();

                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          granted
                              ? 'Permisos de notificaciones habilitados.'
                              : 'Debes permitir las notificaciones desde los ajustes.',
                        ),
                      ),
                    );

                    if (granted) {
                      await NotificationService.instance.syncCurrentUserPlans();
                    }
                  },
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Permitir notificaciones'),
                ),
                const SizedBox(height: 18),
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'ANTICIPACIÓN',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.grey,
                    ),
                  ),
                ),
                Card(
                  child: Column(
                    children: [
                      _reminderOption(
                        title: 'Un día antes',
                        subtitle: '24 horas antes de comenzar',
                        value: _oneDayBefore,
                        keyName: 'reminder_one_day',
                        updateState: () =>
                            _oneDayBefore = !_oneDayBefore,
                      ),
                      const Divider(height: 1),
                      _reminderOption(
                        title: 'Una hora antes',
                        subtitle: '60 minutos antes de comenzar',
                        value: _oneHourBefore,
                        keyName: 'reminder_one_hour',
                        updateState: () =>
                            _oneHourBefore = !_oneHourBefore,
                      ),
                      const Divider(height: 1),
                      _reminderOption(
                        title: '15 minutos antes',
                        subtitle: 'Un aviso poco antes de comenzar',
                        value: _fifteenMinutesBefore,
                        keyName: 'reminder_fifteen_minutes',
                        updateState: () =>
                            _fifteenMinutesBefore =
                                !_fifteenMinutesBefore,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Las preferencias se guardan automáticamente '
                  'en este dispositivo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.grey,
                  ),
                ),
              ],
            ),
    );
  }
}