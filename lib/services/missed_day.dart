import 'progress_stats.dart';

/// A scheduled training day that passed without any completed set and was not skipped.
class MissedDay {
  const MissedDay({required this.date, required this.dayName, required this.session});
  final String date; // yyyy-MM-dd
  final String dayName;
  final String session;
}

const _dayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];

/// Looks at yesterday only. [training] is the plan's day map, [logs] the user's daily logs.
/// Nothing is reported before [challengeStart] or when the plan has no session that day.
MissedDay? findMissedDay({
  required Map<String, dynamic>? training,
  required List<dynamic> logs,
  required DateTime today,
  required DateTime? challengeStart,
}) {
  if (training == null) return null;
  final base = DateTime(today.year, today.month, today.day);
  final yesterday = DateTime(base.year, base.month, base.day - 1);
  if (challengeStart != null) {
    final start = DateTime(challengeStart.year, challengeStart.month, challengeStart.day);
    if (yesterday.isBefore(start)) return null;
  }

  final dayName = _dayNames[yesterday.weekday - 1];
  final day = training[dayName];
  if (day is! Map) return null;
  final exercises = day['exercises'];
  if (day['isRestDay'] == true || exercises is! List || exercises.isEmpty) return null;

  final key = ProgressStats.dateKey(yesterday);
  for (final l in logs) {
    if (l is Map && l['date']?.toString() == key) {
      if (l['skipped']?.toString().trim() == 'true') return null;
      if (l['rest']?.toString().trim() == 'true') return null;
      if (ProgressStats.completedSets(l['exercises']) > 0) return null;
    }
  }
  final session = day['session']?.toString().trim() ?? '';
  return MissedDay(
    date: key,
    dayName: dayName,
    session: session.isEmpty ? 'workout' : session,
  );
}
