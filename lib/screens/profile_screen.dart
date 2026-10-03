import 'package:flutter/material.dart';
import '../models/calendar_models.dart';
import '../services/calendar_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'edit_profile_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _calendarService = CalendarService();
  bool _isLoggingOut = false;
  CalendarConnection _calendar = const CalendarConnection.disconnected();
  List<CalendarEvent> _googleEvents = const [];

  // User data, hardcoded for now, later it comes from the database
  String name = 'Juan García';
  String description =
      'Estudiante de Diseño · 5to semestre · Me gusta el café ☕ y el código 💻';

  final List<String> days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie'];
  int selectedDay = 3;

  final List<List<Map<String, dynamic>>> schedule = [
    [
      {
        'title': 'Cálculo',
        'time': '07:00 - 09:00',
        'room': 'Sal. 201',
        'free': false,
      },
      {'title': 'Libre', 'time': '09:00 - 12:00', 'room': '', 'free': true},
    ],
    [
      {
        'title': 'Diseño',
        'time': '10:00 - 12:00',
        'room': 'Sal. 310',
        'free': false,
      },
    ],
    [
      {
        'title': 'Física',
        'time': '09:00 - 11:00',
        'room': 'Sal. 104',
        'free': false,
      },
    ],
    [
      {
        'title': 'Estadística',
        'time': '08:00 - 10:00',
        'room': 'Sal. 105',
        'free': false,
      },
      {'title': 'Libre', 'time': '10:00 - 13:00', 'room': '', 'free': true},
    ],
    [
      {'title': 'Libre', 'time': '08:00 - 12:00', 'room': '', 'free': true},
    ],
  ];

  String get initials {
    final parts = name.trim().split(' ');
    String letters = parts[0][0];
    if (parts.length > 1) letters += parts[1][0];
    return letters.toUpperCase();
  }

  void openEdit() {
    showEditProfile(
      context: context,
      currentName: name,
      currentDescription: description,
      onSave: (newName, newDescription) {
        setState(() {
          name = newName;
          description = newDescription;
        });
      },
    );
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    try {
      await _authService.logout();
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      authSession.setUnauthenticated();
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  Future<void> _connectCalendar() async {
    await _runCalendarAction(
      action: () => _calendarService.connect(),
      loadingStatus: CalendarConnectionStatus.connecting,
    );
  }

  Future<void> _syncCalendar() async {
    await _runCalendarAction(
      action: () => _calendarService.sync(),
      loadingStatus: CalendarConnectionStatus.syncing,
    );
  }

  Future<void> _runCalendarAction({
    required Future<CalendarSyncResult> Function() action,
    required CalendarConnectionStatus loadingStatus,
  }) async {
    setState(
      () => _calendar = _calendar.copyWith(
        status: loadingStatus,
        clearError: true,
      ),
    );
    try {
      final result = await action();
      if (!mounted) return;
      setState(() {
        _calendar = result.connection;
        _googleEvents = result.events;
      });
      Navigator.pop(context);
    } on CalendarException catch (error) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      setState(
        () => _calendar = _calendar.copyWith(
          status: CalendarConnectionStatus.error,
          errorMessage: error.message,
        ),
      );
    }
  }

  Future<void> _disconnectCalendar() async {
    setState(
      () => _calendar = _calendar.copyWith(
        status: CalendarConnectionStatus.syncing,
        clearError: true,
      ),
    );
    try {
      await _calendarService.disconnect();
      if (!mounted) return;
      setState(() {
        _calendar = const CalendarConnection.disconnected();
        _googleEvents = const [];
      });
      Navigator.pop(context);
    } on CalendarException catch (error) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      setState(
        () => _calendar = _calendar.copyWith(
          status: CalendarConnectionStatus.error,
          errorMessage: error.message,
        ),
      );
    }
  }

  void _openCalendarSync() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CalendarSyncSheet(
        connection: _calendar,
        onConnect: _connectCalendar,
        onSync: _syncCalendar,
        onDisconnect: _disconnectCalendar,
      ),
    );
  }

  List<Map<String, dynamic>> _itemsForDay(int dayIndex) {
    final items = List<Map<String, dynamic>>.from(schedule[dayIndex]);
    for (final event in _googleEvents) {
      if (event.startsAt.weekday != dayIndex + 1) continue;
      items.add({
        'title': event.title,
        'time': event.allDay
            ? 'Todo el día'
            : '${_time(event.startsAt)} - ${_time(event.endsAt)}',
        'room': event.location ?? '',
        'free': false,
        'source': event.source,
      });
    }
    return items;
  }

  String _time(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final dayItems = _itemsForDay(selectedDay);
    final freeWindows = dayItems.where((c) => c['free'] == true).length;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF9AD6F2), Color(0xFFCBE9F8)],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 34,
                            backgroundColor: AppColors.blue,
                            child: Text(
                              initials,
                              style: const TextStyle(
                                fontSize: 22,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 2,
                            bottom: 2,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: AppColors.green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              description,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF4A5A66),
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: openEdit,
                              icon: const Icon(Icons.edit_outlined, size: 14),
                              label: const Text(
                                'Editar perfil',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF3D4D59),
                                backgroundColor: const Color(0x66FFFFFF),
                                side: const BorderSide(color: Colors.white),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _isLoggingOut ? null : _logout,
                                  icon: const Icon(Icons.logout, size: 17),
                                  label: Text(
                                    _isLoggingOut
                                        ? 'Cerrando sesión...'
                                        : 'Cerrar sesión',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Card with the 3 stats
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0x55FFFFFF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        statItem(Icons.bolt, '12', 'Actividades'),
                        statItem(Icons.people, '8', 'Amigos'),
                        statItem(Icons.hourglass_bottom, '6h', 'Horas libres'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              transform: Matrix4.translationValues(0, -12, 0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(16),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Mi horario',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.greenLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFBDE8CE)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.circle,
                              size: 8,
                              color: AppColors.green,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$freeWindows ventana libre',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _calendarAction(),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_calendar.errorMessage != null)
                    _calendarError(_calendar.errorMessage!),
                  const SizedBox(height: 14),
                  // The day buttons
                  Row(
                    children: List.generate(days.length, (i) {
                      final isSelected = i == selectedDay;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => selectedDay = i),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.rosewood
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x14000000),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                days[i],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF444444),
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 14),
                  ...dayItems.map((item) => classCard(item)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget statItem(IconData icon, String number, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 14, color: const Color(0xFFE0A93B)),
          const SizedBox(height: 4),
          Text(
            number,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF4A5A66)),
          ),
        ],
      ),
    );
  }

  Widget _calendarAction() {
    final connected =
        _calendar.status == CalendarConnectionStatus.connected ||
        _calendar.status == CalendarConnectionStatus.syncing;
    final loading =
        _calendar.status == CalendarConnectionStatus.connecting ||
        _calendar.status == CalendarConnectionStatus.syncing;
    return OutlinedButton.icon(
      onPressed: loading ? null : _openCalendarSync,
      icon: Icon(
        connected ? Icons.check_circle_outline : Icons.calendar_month_outlined,
        size: 16,
      ),
      label: Text(
        loading
            ? 'Sincronizando...'
            : connected
            ? 'Google Calendar'
            : 'Conectar calendario',
        style: const TextStyle(fontSize: 11),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: connected ? AppColors.green : AppColors.blue,
        side: BorderSide(
          color: connected ? const Color(0xFFBDE8CE) : AppColors.blue,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }

  Widget _calendarError(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: Colors.redAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget classCard(Map<String, dynamic> item) {
    final bool isFree = item['free'];
    final Color borderColor = isFree ? AppColors.green : AppColors.blue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isFree ? AppColors.greenLight : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isFree ? Border.all(color: const Color(0xFFBDE8CE)) : null,
        boxShadow: isFree
            ? null
            : const [BoxShadow(color: Color(0x14000000), blurRadius: 8)],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 4, color: borderColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item['title'],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isFree ? AppColors.green : Colors.black,
                          ),
                        ),
                        if (isFree)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'LIBRE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (item['source'] == 'google')
                          const Icon(
                            Icons.calendar_month_outlined,
                            size: 16,
                            color: AppColors.blue,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppColors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item['time'],
                          style: const TextStyle(fontSize: 13),
                        ),
                        if (item['room'] != '') ...[
                          const SizedBox(width: 14),
                          const Icon(
                            Icons.meeting_room_outlined,
                            size: 14,
                            color: AppColors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item['room'],
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarSyncSheet extends StatelessWidget {
  const _CalendarSyncSheet({
    required this.connection,
    required this.onConnect,
    required this.onSync,
    required this.onDisconnect,
  });

  final CalendarConnection connection;
  final VoidCallback onConnect;
  final VoidCallback onSync;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final isConnected =
        connection.status == CalendarConnectionStatus.connected ||
        connection.status == CalendarConnectionStatus.syncing;
    final isLoading =
        connection.status == CalendarConnectionStatus.connecting ||
        connection.status == CalendarConnectionStatus.syncing;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD5D9DD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(Icons.calendar_month, color: AppColors.blue),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Google Calendar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isConnected
                ? 'Tus eventos se muestran en el horario y se mantienen en modo solo lectura.'
                : 'Conecta tu calendario para ver tus eventos junto a tu horario.',
            style: const TextStyle(fontSize: 13, color: AppColors.grey),
          ),
          if (connection.email != null) ...[
            const SizedBox(height: 12),
            Text(
              connection.email!,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
          if (connection.lastSyncedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Última sincronización: ${_formatDate(connection.lastSyncedAt!)}',
              style: const TextStyle(fontSize: 12, color: AppColors.grey),
            ),
          ],
          const SizedBox(height: 18),
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (isConnected) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onSync,
                icon: const Icon(Icons.sync),
                label: const Text('Sincronizar ahora'),
              ),
            ),
            TextButton(
              onPressed: onDisconnect,
              child: const Text('Desconectar Google Calendar'),
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onConnect,
                icon: const Icon(Icons.link),
                label: const Text('Conectar Google Calendar'),
              ),
            ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
