import 'dart:convert';

/// Consistency numbers derived from the daily logs. Pure and testable.
class ProgressStats {
  const ProgressStats({
    required this.streak,
    required this.workouts,
    required this.last7,
    required this.weekAverage,
    required this.recent,
  });

  /// Consecutive active days ending today (or yesterday if today is not done yet).
  final int streak;

  /// Days with at least one completed set.
  final int workouts;

  /// Checklist completion (0..1) for the last 7 days, oldest first, ending today.
  final List<double> last7;

  /// Mean of [last7].
  final double weekAverage;

  /// Most recent logged workouts, newest first.
  final List<RecentSession> recent;

  static const empty = ProgressStats(
    streak: 0,
    workouts: 0,
    last7: [0, 0, 0, 0, 0, 0, 0],
    weekAverage: 0,
    recent: [],
  );

  /// A day counts as active when at least half the checklist is done or a
  /// workout was logged.
  static const activeThreshold = 0.5;

  static String dateKey(DateTime d) => d.toIso8601String().split('T')[0];

  static double checklistCompletion(Object? raw) {
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return 0;
    try {
      final map = jsonDecode(text);
      if (map is! Map || map.isEmpty) return 0;
      final done = map.values.where((v) => v == true || v == 'true').length;
      return done / map.length;
    } catch (_) {
      return 0;
    }
  }

  /// Number of completed sets in a log's exercises JSON.
  static int completedSets(Object? raw) {
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return 0;
    try {
      final list = jsonDecode(text);
      if (list is! List) return 0;
      var n = 0;
      for (final ex in list) {
        final sets = ex is Map ? ex['sets'] : null;
        if (sets is! List) continue;
        n += sets.where((s) => s is Map && s['done'] == true).length;
      }
      return n;
    } catch (_) {
      return 0;
    }
  }

  static ProgressStats fromLogs(List<dynamic> logs, DateTime today) {
    final byDate = <String, Map>{};
    for (final l in logs) {
      if (l is Map && l['date'] != null) {
        byDate[l['date'].toString()] = l;
      }
    }

    bool active(DateTime d) {
      final log = byDate[dateKey(d)];
      if (log == null) return false;
      return checklistCompletion(log['checklist']) >= activeThreshold ||
          completedSets(log['exercises']) > 0;
    }

    final base = DateTime(today.year, today.month, today.day);

    var streak = 0;
    for (var i = 0; i < 400; i++) {
      final d = base.subtract(Duration(days: i));
      if (active(d)) {
        streak++;
      } else if (i == 0) {
        continue; // today may simply not be done yet
      } else {
        break;
      }
    }

    final last7 = <double>[
      for (var i = 6; i >= 0; i--)
        checklistCompletion(
          byDate[dateKey(base.subtract(Duration(days: i)))]?['checklist'],
        ),
    ];
    final avg = last7.reduce((a, b) => a + b) / last7.length;

    final workoutLogs =
        byDate.values.where((l) => completedSets(l['exercises']) > 0).toList()
          ..sort((a, b) => b['date'].toString().compareTo(a['date'].toString()));

    return ProgressStats(
      streak: streak,
      workouts: workoutLogs.length,
      last7: last7,
      weekAverage: avg,
      recent: workoutLogs
          .take(5)
          .map(
            (l) => RecentSession(
              date: l['date'].toString(),
              session: (l['session']?.toString().trim().isEmpty ?? true)
                  ? 'Workout'
                  : l['session'].toString().trim(),
              sets: completedSets(l['exercises']),
            ),
          )
          .toList(),
    );
  }
}

class RecentSession {
  const RecentSession({
    required this.date,
    required this.session,
    required this.sets,
  });
  final String date;
  final String session;
  final int sets;
}
