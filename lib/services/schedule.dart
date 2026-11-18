import 'dart:convert';
import 'progress_stats.dart';

const weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool _isRestLike(Object? day) {
  if (day is! Map) return true;
  final session = day['session']?.toString().toLowerCase() ?? '';
  final exercises = day['exercises'];
  return day['isRestDay'] == true ||
      session.contains('rest') ||
      session.contains('recovery') ||
      exercises is! List ||
      exercises.isEmpty;
}

/// Weekdays that hold a real training session, Monday first.
List<String> trainingDays(Map<String, dynamic>? training) {
  if (training == null) return const [];
  return [
    for (final d in weekdayNames)
      if (!_isRestLike(training[d])) d,
  ];
}

/// A log counts as done when a set was completed or the day was skipped. Rest logs never count.
bool logCleared(Map log) {
  if (log['rest']?.toString().trim() == 'true') return false;
  if (log['skipped']?.toString().trim() == 'true') return true;
  return ProgressStats.completedSets(log['exercises']) > 0;
}

/// Which plan session [date] should do, or null when it is a rest day.
///
/// The plan stays fixed; the week slides around what actually happened. Walking Monday up to the day before
/// [date]: a rest log hands its session on to the next day, a done log uses up the session it was for
/// (`plannedDay`, or the weekday's own), and a day with no log is assumed to have followed the plan.
/// Sessions pushed past the end of the week are dropped. Saturday and Sunday can absorb a slipped session
/// even when the plan has them as recovery or rest.
String? suggestedSession({
  required Map<String, dynamic>? training,
  required DateTime date,
  required List<dynamic> logs,
  DateTime? challengeStart,
}) {
  final base = trainingDays(training);
  if (base.isEmpty) return null;
  final target = dateOnly(date);
  final monday = target.subtract(Duration(days: target.weekday - DateTime.monday));
  final start = challengeStart == null ? null : dateOnly(challengeStart);

  final byDate = <String, Map>{
    for (final l in logs)
      if (l is Map && l['date'] != null) l['date'].toString(): l,
  };

  bool eligible(DateTime d) => base.contains(weekdayNames[d.weekday - 1]) || d.weekday >= DateTime.saturday;

  final queue = [...base];
  for (var d = monday; d.isBefore(target); d = DateTime(d.year, d.month, d.day + 1)) {
    if (start != null && d.isBefore(start)) continue;
    final log = byDate[ProgressStats.dateKey(d)];
    if (log != null && log['rest']?.toString().trim() == 'true') continue;
    if (log != null && logCleared(log)) {
      final planned = log['plannedDay']?.toString().trim() ?? '';
      queue.remove(planned.isEmpty ? weekdayNames[d.weekday - 1] : planned);
    } else if (eligible(d) && queue.isNotEmpty) {
      queue.removeAt(0);
    }
  }
  if (queue.isEmpty || !eligible(target)) return null;
  return queue.first;
}

/// Sessions of the week that are still open for [date], in plan order. Used for the "something else" choices.
List<String> openSessions({
  required Map<String, dynamic>? training,
  required DateTime date,
  required List<dynamic> logs,
}) {
  final base = trainingDays(training);
  final target = dateOnly(date);
  final monday = target.subtract(Duration(days: target.weekday - DateTime.monday));
  final done = <String>{};
  for (final l in logs) {
    if (l is! Map || l['date'] == null) continue;
    final d = DateTime.tryParse(l['date'].toString());
    if (d == null) continue;
    final day = dateOnly(d);
    if (day.isBefore(monday) || day.isAfter(monday.add(const Duration(days: 6)))) continue;
    if (day == target || !logCleared(l)) continue;
    final planned = l['plannedDay']?.toString().trim() ?? '';
    done.add(planned.isEmpty ? weekdayNames[day.weekday - 1] : planned);
  }
  return [for (final d in base) if (!done.contains(d)) d];
}

/// Exercises JSON of a log as a list, or empty when it is blank or malformed.
List<dynamic> parseLoggedExercises(Object? raw) {
  final text = raw?.toString().trim() ?? '';
  if (text.isEmpty) return const [];
  try {
    final v = jsonDecode(text);
    return v is List ? v : const [];
  } catch (_) {
    return const [];
  }
}
