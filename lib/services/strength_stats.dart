import 'dart:convert';

/// One workout's best set for an exercise.
class StrengthPoint {
  const StrengthPoint({
    required this.date,
    required this.weight,
    required this.reps,
    required this.e1rm,
  });

  final String date;
  final double weight;
  final int reps;

  /// Estimated one-rep max (Epley), so sets of different rep counts can be compared.
  final double e1rm;
}

/// Everything logged for one exercise, oldest session first.
class ExerciseHistory {
  const ExerciseHistory({required this.name, required this.sessions});

  final String name;
  final List<StrengthPoint> sessions;

  StrengthPoint get latest => sessions.last;

  double get bestE1rm =>
      sessions.map((s) => s.e1rm).reduce((a, b) => a > b ? a : b);

  /// True when the latest session beat every earlier one. A first-ever session is not a record.
  bool get latestIsPr {
    if (sessions.length < 2) return false;
    final earlier = sessions
        .sublist(0, sessions.length - 1)
        .map((s) => s.e1rm)
        .reduce((a, b) => a > b ? a : b);
    return latest.e1rm > earlier;
  }
}

/// Personal records and per-exercise strength history, derived only from the daily logs.
class StrengthStats {
  const StrengthStats._();

  static const maxRepsForEstimate = 30;

  /// Epley estimate. A single rep is the weight itself; reps are capped so a 100-rep set
  /// cannot produce a nonsense maximum.
  static double estimateOneRepMax(double weight, int reps) {
    if (weight <= 0 || reps <= 0) return 0;
    if (reps == 1) return weight;
    final r = reps > maxRepsForEstimate ? maxRepsForEstimate : reps;
    return weight * (1 + r / 30);
  }

  /// The first number in text such as "60", "62.5" or "60 kg"; null when there is none.
  static double? parseNumber(Object? raw) {
    final m = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(raw?.toString() ?? '');
    if (m == null) return null;
    return double.tryParse(m.group(0)!.replaceAll(',', '.'));
  }

  /// Histories sorted by most recently trained first. Only completed sets with a positive
  /// weight and rep count count; bad rows are skipped rather than failing.
  static List<ExerciseHistory> fromLogs(List<dynamic> logs) {
    final dated = <MapEntry<String, List>>[];
    for (final l in logs) {
      if (l is! Map || l['date'] == null) continue;
      final text = l['exercises']?.toString().trim() ?? '';
      if (text.isEmpty) continue;
      try {
        final decoded = jsonDecode(text);
        if (decoded is List) dated.add(MapEntry(l['date'].toString(), decoded));
      } catch (_) {
        continue;
      }
    }
    dated.sort((a, b) => a.key.compareTo(b.key));

    final names = <String, String>{}; // normalised -> display
    final points = <String, List<StrengthPoint>>{};

    for (final day in dated) {
      final bestToday = <String, StrengthPoint>{};
      for (final ex in day.value) {
        if (ex is! Map || ex['sets'] is! List) continue;
        final name = ex['name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        final key = name.toLowerCase();
        for (final s in ex['sets'] as List) {
          if (s is! Map || s['done'] != true) continue;
          final w = parseNumber(s['weight']);
          final r = parseNumber(s['reps'])?.round();
          if (w == null || r == null || w <= 0 || r <= 0) continue;
          final e = estimateOneRepMax(w, r);
          final current = bestToday[key];
          if (current == null || e > current.e1rm) {
            names.putIfAbsent(key, () => name);
            bestToday[key] =
                StrengthPoint(date: day.key, weight: w, reps: r, e1rm: e);
          }
        }
      }
      bestToday.forEach((k, p) => points.putIfAbsent(k, () => []).add(p));
    }

    final out = [
      for (final e in points.entries)
        ExerciseHistory(name: names[e.key]!, sessions: e.value),
    ]..sort((a, b) => b.latest.date.compareTo(a.latest.date));
    return out;
  }

  /// Exercises whose latest session is a record dated within the last [days] days.
  static List<ExerciseHistory> recentRecords(
    List<ExerciseHistory> all,
    DateTime today, {
    int days = 14,
  }) {
    final cutoff = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: days));
    final key =
        '${cutoff.year.toString().padLeft(4, '0')}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}';
    return all
        .where((h) => h.latestIsPr && h.latest.date.compareTo(key) >= 0)
        .toList();
  }
}
