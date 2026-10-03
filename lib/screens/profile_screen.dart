import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/profile_models.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/schedule_service.dart';
import '../theme/app_theme.dart';
import '../viewmodels/profile_view_model.dart';
import 'edit_profile_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  late final ProfileViewModel _profileViewModel;
  final _picker = ImagePicker();
  final _scheduleService = ScheduleService();
  bool _isLoggingOut = false;
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _googleConnected = false;
  String? _errorMessage;
  UserProfile? _profile;

  final List<String> days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie'];
  int selectedDay = (DateTime.now().weekday - 1).clamp(0, 4);
  late final List<DateTime> _weekdays = _currentWeekdays();
  List<DayGaps> _weekGaps = const [];

  @override
  void initState() {
    super.initState();
    _profileViewModel = ProfileViewModel();
    _loadProfile();
  }

  @override
  void dispose() {
    _profileViewModel.dispose();
    super.dispose();
  }

  List<DateTime> _currentWeekdays() {
    final today = DateTime.now();
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return List.generate(5, (index) {
      final date = monday.add(Duration(days: index));
      return DateTime(date.year, date.month, date.day);
    });
  }

  String get initials {
    final parts = (_profile?.name ?? '').trim().split(' ');
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    String letters = parts[0][0];
    if (parts.length > 1) letters += parts[1][0];
    return letters.toUpperCase();
  }

  void openEdit() {
    showEditProfile(
      context: context,
      currentName: _profile?.name ?? '',
      currentDescription: _profile?.bio ?? '',
      currentAvatarUrl: _profile?.avatarUrl,
      onTakePhoto: _takeProfilePhoto,
      onSave: (newName, newDescription) async {
        try {
          final profile = await _profileViewModel.updateProfile(
            name: newName.trim(),
            bio: newDescription.trim(),
          );
          if (mounted && profile != null) setState(() => _profile = profile);
          if (profile == null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _profileViewModel.errorMessage ??
                      'No pudimos actualizar tu perfil.',
                ),
              ),
            );
          }
        } on ProfileException catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(error.message)));
          }
        }
      },
    );
  }

  Future<String?> _takeProfilePhoto() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024, // el backend la reduce a 512 igual y acepta hasta 5 MB
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front,
      );
      if (photo == null) return null; // el usuario canceló
      final profile = await _profileViewModel.uploadAvatar(photo.path);
      if (mounted && profile != null) setState(() => _profile = profile);
      if (profile == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _profileViewModel.errorMessage ??
                  'No pudimos subir la foto de perfil.',
            ),
          ),
        );
      }
      return profile?.avatarUrl;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos abrir la cámara.')),
        );
      }
    }
    return null;
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final profile = await _profileViewModel.load();
      if (profile == null) {
        throw ProfileException(
          _profileViewModel.errorMessage ?? 'No pudimos cargar tu perfil.',
        );
      }
      await _loadSchedule();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } on ProfileException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    }
  }

  Future<void> _loadSchedule() async {
    try {
      final status = await _scheduleService.getGoogleStatus();
      _googleConnected = status.connected;
    } on ScheduleException {
      _googleConnected = false;
    }

    final gaps = <DayGaps>[];
    for (final date in _weekdays) {
      try {
        gaps.add(await _scheduleService.getGaps(date: date));
      } on ScheduleException {
        // An unavailable schedule is rendered as an empty state.
      }
    }
    _weekGaps = gaps;
  }

  Future<void> _connectCalendar() async {
    setState(() => _isSyncing = true);
    try {
      final authorization = await GoogleSignIn.instance.authorizationClient
          .authorizeServer(const [
            'https://www.googleapis.com/auth/calendar.readonly',
          ]);
      final authCode = authorization?.serverAuthCode;
      if (authCode == null || authCode.isEmpty) {
        throw const ScheduleException(
          'Google no devolvió un código de autorización.',
        );
      }
      await _scheduleService.syncGoogle(authCode: authCode);
      await _loadSchedule();
      if (mounted) Navigator.pop(context);
    } on ScheduleException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
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

  Future<void> _refreshCalendar() async {
    setState(() => _isSyncing = true);
    try {
      await _scheduleService.refreshGoogle();
      await _loadSchedule();
      if (mounted) Navigator.pop(context);
    } on ScheduleException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
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
        connected: _googleConnected,
        isLoading: _isSyncing,
        onConnect: _connectCalendar,
        onRefresh: _refreshCalendar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final dayGaps = _weekGaps
        .where((gaps) => gaps.date == _weekdays[selectedDay])
        .expand((gaps) => gaps.free)
        .toList(growable: false);
    final freeWindows = dayGaps.length;

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
                            backgroundImage: _profile?.avatarUrl == null
                                ? null
                                : NetworkImage(_profile!.avatarUrl!),
                            child: _profile?.avatarUrl == null
                                ? Text(
                                    initials,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  )
                                : null,
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
                              _profile?.name ?? '',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _profile?.bio ?? '',
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
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0x55FFFFFF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        statItem(Icons.bolt, '—', 'Actividades'),
                        statItem(Icons.people, '—', 'Amigos'),
                        statItem(
                          Icons.hourglass_bottom,
                          _hoursFor(dayGaps),
                          'Horas libres',
                        ),
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
                  if (_errorMessage != null) _calendarError(_errorMessage!),
                  const SizedBox(height: 14),
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
                  if (dayGaps.isEmpty) _emptySchedule(),
                  ...dayGaps.map(classCard),
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
    return OutlinedButton.icon(
      onPressed: _isSyncing ? null : _openCalendarSync,
      icon: Icon(
        _googleConnected
            ? Icons.check_circle_outline
            : Icons.calendar_month_outlined,
        size: 16,
      ),
      label: Text(
        _isSyncing
            ? 'Sincronizando...'
            : _googleConnected
            ? 'Google Calendar'
            : 'Conectar calendario',
        style: const TextStyle(fontSize: 11),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: _googleConnected ? AppColors.green : AppColors.blue,
        side: BorderSide(
          color: _googleConnected ? const Color(0xFFBDE8CE) : AppColors.blue,
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

  Widget _emptySchedule() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.event_busy_outlined, size: 36, color: AppColors.grey),
          SizedBox(height: 10),
          Text(
            'No hay bloques de horario para este día.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.grey),
          ),
        ],
      ),
    );
  }

  String _hoursFor(List<FreeInterval> gaps) {
    final minutes = gaps.fold<int>(
      0,
      (total, gap) => total + gap.end.difference(gap.start).inMinutes,
    );
    return '${(minutes / 60).toStringAsFixed(1)}h';
  }

  String _time(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget classCard(FreeInterval interval) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.greenLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBDE8CE)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 4, color: AppColors.green),
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
                          'Ventana libre',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.green,
                          ),
                        ),
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
                          '${_time(interval.start)} - ${_time(interval.end)}',
                          style: const TextStyle(fontSize: 13),
                        ),
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
    required this.connected,
    required this.isLoading,
    required this.onConnect,
    required this.onRefresh,
  });

  final bool connected;
  final bool isLoading;
  final VoidCallback onConnect;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
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
            connected
                ? 'Los intervalos de tu calendario se muestran en modo solo lectura.'
                : 'Conecta Google Calendar para calcular tu horario real.',
            style: const TextStyle(fontSize: 13, color: AppColors.grey),
          ),
          const SizedBox(height: 18),
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (connected) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.sync),
                label: const Text('Actualizar calendario'),
              ),
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
}
