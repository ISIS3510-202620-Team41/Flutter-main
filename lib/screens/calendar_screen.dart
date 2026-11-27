import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/local_database_facade.dart';
import '../models/joined_activity_record.dart';
import '../navigation/app_routes.dart';
import '../theme/app_theme.dart';
import '../viewmodels/joined_activities_view_model.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final JoinedActivitiesViewModel _viewModel = JoinedActivitiesViewModel(
    LocalDatabaseFacade.instance.joinedActivities ??
        (throw StateError('The local database has not been initialized.')),
  )..load();

  DateTime _selectedDate = DateTime.now();
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _showPending = true;
  bool _rememberDate = false;
  static const _rememberKey = 'calendar_remember_selected_date';
  static const _dateKey = 'calendar_selected_date';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final savedDate = DateTime.tryParse(prefs.getString(_dateKey) ?? '');
    setState(() {
      _rememberDate = prefs.getBool(_rememberKey) ?? false;
      if (_rememberDate && savedDate != null) {
        _selectedDate = DateTime(savedDate.year, savedDate.month, savedDate.day);
        _visibleMonth = DateTime(savedDate.year, savedDate.month);
      }
    });
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime? _activityDate(JoinedActivityRecord item) =>
      DateTime.tryParse(item.activity.startTime)?.toLocal();

  List<JoinedActivityRecord> _activitiesForSelectedDay() {
    return _viewModel.activities.where((item) {
      if (item.isPendingLeave || (!_showPending && item.isPendingJoin)) return false;
      final date = _activityDate(item);
      return date != null && _sameDay(date, _selectedDate);
    }).toList()
      ..sort((a, b) => a.activity.startTime.compareTo(b.activity.startTime));
  }

  bool _hasActivity(DateTime date) => _viewModel.activities.any((item) {
    if (item.isPendingLeave || (!_showPending && item.isPendingJoin)) return false;
    final activityDate = _activityDate(item);
    return activityDate != null && _sameDay(activityDate, date);
  });

  Future<void> _selectDate(DateTime date) async {
    setState(() => _selectedDate = DateTime(date.year, date.month, date.day));
    if (_rememberDate) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dateKey, _selectedDate.toIso8601String());
    }
  }

  Future<void> _toggleRemember(bool value) async {
    setState(() => _rememberDate = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberKey, value);
    if (value) await prefs.setString(_dateKey, _selectedDate.toIso8601String());
  }

  Future<void> _exportCalendar() async {
    final records = _viewModel.activities.where((item) =>
        !item.isPendingLeave && (_showPending || !item.isPendingJoin)).toList();
    final lines = <String>[
      'BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//Llamalla//Mi agenda//ES',
    ];
    for (final item in records) {
      final start = DateTime.tryParse(item.activity.startTime)?.toUtc();
      final end = DateTime.tryParse(item.activity.endTime)?.toUtc();
      if (start == null || end == null) continue;
      String stamp(DateTime value) =>
          '${value.year.toString().padLeft(4, '0')}${value.month.toString().padLeft(2, '0')}${value.day.toString().padLeft(2, '0')}T${value.hour.toString().padLeft(2, '0')}${value.minute.toString().padLeft(2, '0')}${value.second.toString().padLeft(2, '0')}Z';
      String escape(String value) => value.replaceAll('\\', '\\\\')
          .replaceAll(';', r'\;').replaceAll(',', r'\,')
          .replaceAll('\n', r'\n');
      lines.addAll([
        'BEGIN:VEVENT',
        'UID:${item.activity.id}@llamalla',
        'DTSTART:${stamp(start)}',
        'DTEND:${stamp(end)}',
        'SUMMARY:${escape(item.activity.title)}',
        'LOCATION:${escape(item.activity.locationName)}',
        'END:VEVENT',
      ]);
    }
    lines.add('END:VCALENDAR');
    await Clipboard.setData(ClipboardData(text: lines.join('\r\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calendario .ics copiado. Pégalo en un archivo con extensión .ics para importarlo.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        final selectedActivities = _activitiesForSelectedDay();
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.blue,
            foregroundColor: const Color(0xFF172A3A),
            leading: IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back),
            ),
            title: const Text('Mi agenda', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                    children: [
                      if (_viewModel.isOffline)
                        _notice('Sin conexión. Puedes consultar las actividades disponibles.'),
                      if (_viewModel.refreshError != null)
                        _notice('No se pudo actualizar la agenda. Se muestran los datos guardados.'),
                      if (_viewModel.errorMessage != null)
                        _notice('No pudimos cargar tus actividades: ${_viewModel.errorMessage}'),
                      _optionsCard(),
                      const SizedBox(height: 18),
                      _calendarCard(),
                      const SizedBox(height: 22),
                      Text(
                        _dateTitle(_selectedDate),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF202A38)),
                      ),
                      const SizedBox(height: 12),
                      if (_viewModel.isLoading && _viewModel.activities.isEmpty)
                        const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                      else if (selectedActivities.isEmpty)
                        const Text('No tienes actividades para este día.', style: TextStyle(color: AppColors.grey, fontSize: 15))
                      else
                        ...selectedActivities.map(_activityTile),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: _exportCalendar,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        foregroundColor: const Color(0xFF172A3A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Exportar calendario', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _notice(String message) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.blueLight, borderRadius: BorderRadius.circular(16)),
    child: Text(message, style: const TextStyle(fontSize: 15, color: Color(0xFF202A38))),
  );

  Widget _optionsCard() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE1E6EB))),
    child: Column(children: [
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Mostrar inscripciones pendientes', style: TextStyle(fontSize: 15)),
        value: _showPending,
        activeTrackColor: AppColors.blue,
        onChanged: (value) => setState(() => _showPending = value),
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Recordar la fecha seleccionada', style: TextStyle(fontSize: 15)),
        value: _rememberDate,
        activeTrackColor: AppColors.blue,
        onChanged: _toggleRemember,
      ),
    ]),
  );

  Widget _calendarCard() {
    final firstWeekday = DateTime(_visibleMonth.year, _visibleMonth.month, 1).weekday;
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final rows = ((firstWeekday - 1 + daysInMonth) / 7).ceil();
    final monthNames = const ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), border: Border.all(color: const Color(0xFFE1E6EB))),
      child: Column(children: [
        Row(children: [
          IconButton(onPressed: () => setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1)), icon: const Icon(Icons.arrow_back_ios_new)),
          Expanded(child: Text('${_capitalize(monthNames[_visibleMonth.month - 1])} de ${_visibleMonth.year}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          IconButton(onPressed: () => setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1)), icon: const Icon(Icons.arrow_forward_ios)),
        ]),
        const SizedBox(height: 6),
        Row(children: ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'].map((day) => Expanded(child: Center(child: Text(day, style: const TextStyle(color: AppColors.grey, fontWeight: FontWeight.w700))))).toList()),
        const SizedBox(height: 8),
        ...List.generate(rows, (row) => Row(
          children: List.generate(7, (column) {
            final day = row * 7 + column - (firstWeekday - 1) + 1;
            if (day < 1 || day > daysInMonth) return const Expanded(child: SizedBox(height: 58));
            final date = DateTime(_visibleMonth.year, _visibleMonth.month, day);
            final selected = _sameDay(date, _selectedDate);
            final marked = _hasActivity(date);
            return Expanded(child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () => _selectDate(date),
              child: SizedBox(height: 58, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 42, height: 42, alignment: Alignment.center, decoration: BoxDecoration(color: selected ? AppColors.blue : Colors.transparent, shape: BoxShape.circle), child: Text('$day', style: TextStyle(fontSize: 15, fontWeight: selected || marked ? FontWeight.w700 : FontWeight.normal, color: const Color(0xFF202A38)))),
                if (marked) Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.rosewood, shape: BoxShape.circle)) else const SizedBox(height: 6),
              ])),
            ));
          }),
        )),
      ]),
    );
  }

  Widget _activityTile(JoinedActivityRecord item) {
    final start = DateTime.tryParse(item.activity.startTime)?.toLocal();
    final end = DateTime.tryParse(item.activity.endTime)?.toLocal();
    String clock(DateTime? date) => date == null ? '--:--' : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE5EAF0))),
      child: ListTile(
        onTap: () => Navigator.pushNamed(context, AppRoutes.activityDetail, arguments: item.activity.id),
        leading: Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.blueLight, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.event, color: Color(0xFF263746))),
        title: Text(item.activity.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${clock(start)} - ${clock(end)}\n${item.activity.locationName}${item.isPendingJoin ? '\nInscripción pendiente' : ''}'),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  String _dateTitle(DateTime date) {
    const weekdays = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
    const months = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
    return '${_capitalize(weekdays[date.weekday - 1])} ${date.day} de ${months[date.month - 1]}';
  }

  String _capitalize(String value) => value[0].toUpperCase() + value.substring(1);
}