import 'dart:convert';

/// One exercise's progression result for the finished week.
class WeekChange {
  const WeekChange({required this.name, required this.weight, required this.increased});
  final String name;
  final String weight;
  final bool increased;
}

/// Recap of the week that just ended, built by the server from logged sets.
class WeekReport {
  const WeekReport({required this.week, required this.sessions, required this.changes});

  final int week;
  final int sessions;
  final List<WeekChange> changes;

  /// Returns null for blank, malformed or empty-of-content input (for example week 1).
  static WeekReport? parse(Object? stored) {
    final text = stored?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    try {
      final m = jsonDecode(text);
      if (m is! Map) return null;
      final week = m['week'];
      final sessions = m['sessions'];
      if (week is! num || sessions is! num) return null;
      final changes = <WeekChange>[];
      final raw = m['changes'];
      if (raw is List) {
        for (final c in raw) {
          if (c is! Map) continue;
          final name = c['name'];
          final weight = c['weight'];
          if (name is! String || name.trim().isEmpty || weight == null) continue;
          changes.add(
            WeekChange(
              name: name.trim(),
              weight: weight.toString(),
              increased: c['action'] == 'INCREASE',
            ),
          );
        }
      }
      return WeekReport(
        week: week.toInt(),
        sessions: sessions.toInt(),
        changes: changes,
      );
    } catch (_) {
      return null;
    }
  }

  int get increases => changes.where((c) => c.increased).length;

  /// "3 sessions logged" / "No sessions logged".
  String get sessionsLabel => sessions <= 0
      ? 'No sessions logged'
      : '$sessions ${sessions == 1 ? 'session' : 'sessions'} logged';
}
