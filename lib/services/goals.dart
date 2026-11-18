import 'dart:convert';

/// The user's targets: a goal weight and waist, and the date they are aiming for.
/// Every field is optional.
class Goals {
  const Goals({this.targetWeight, this.targetWaist, this.eventDate});

  final double? targetWeight; // kg
  final double? targetWaist; // cm
  final DateTime? eventDate; // date only

  static const empty = Goals();

  /// Same limits the server enforces.
  static const minWeight = 20.0;
  static const maxWeight = 400.0;
  static const minWaist = 30.0;
  static const maxWaist = 250.0;

  bool get isEmpty =>
      targetWeight == null && targetWaist == null && eventDate == null;

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        if (targetWeight != null) 'targetWeight': targetWeight,
        if (targetWaist != null) 'targetWaist': targetWaist,
        if (eventDate != null) 'eventDate': dateKey(eventDate!),
      };

  /// Parses the stored JSON string. Blank or unreadable input means no goals.
  static Goals parse(Object? stored) {
    final text = stored?.toString().trim() ?? '';
    if (text.isEmpty) return empty;
    try {
      final m = jsonDecode(text);
      if (m is! Map) return empty;
      double? numOf(Object? v) => v is num ? v.toDouble() : null;
      DateTime? date;
      final raw = m['eventDate'];
      if (raw is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
        final d = DateTime.tryParse(raw);
        if (d != null) date = DateTime(d.year, d.month, d.day);
      }
      return Goals(
        targetWeight: numOf(m['targetWeight']),
        targetWaist: numOf(m['targetWaist']),
        eventDate: date,
      );
    } catch (_) {
      return empty;
    }
  }

  /// The date to count down to: the chosen event date, otherwise the last day of the challenge.
  static DateTime? effectiveEventDate(
    Goals goals,
    DateTime? challengeStart,
    int challengeDays,
  ) {
    if (goals.eventDate != null) return goals.eventDate;
    if (challengeStart == null || challengeDays < 1) return null;
    final s = DateTime(challengeStart.year, challengeStart.month, challengeStart.day);
    return DateTime(s.year, s.month, s.day + challengeDays - 1);
  }

  /// Whole days from today to [event]; 0 on the day, negative once it has passed.
  static int daysUntil(DateTime event, DateTime now) {
    final a = DateTime(now.year, now.month, now.day);
    final b = DateTime(event.year, event.month, event.day);
    return b.difference(a).inDays;
  }
}

enum GoalStatus { noData, reached, ahead, onTrack, behind }

/// How far one measurement has moved toward its target, compared with how much time has passed.
class MetricProgress {
  const MetricProgress({
    required this.status,
    required this.start,
    required this.current,
    required this.target,
    required this.fraction,
    required this.timeFraction,
  });

  final GoalStatus status;
  final double? start;
  final double? current;
  final double target;

  /// Share of the distance from start to target covered, 0..1.
  final double fraction;

  /// Share of the time between challenge start and the event that has passed, 0..1.
  final double timeFraction;

  double? get remaining => current == null ? null : (target - current!).abs();

  static const tolerance = 0.1;

  /// [start] is the first recorded value, [current] the latest. Direction (losing or gaining) is
  /// taken from start versus target, so the same logic serves weight loss and weight gain.
  static MetricProgress compute({
    required double? start,
    required double? current,
    required double target,
    required DateTime challengeStart,
    required DateTime event,
    required DateTime now,
  }) {
    final time = _timeFraction(challengeStart, event, now);
    if (start == null || current == null) {
      return MetricProgress(
        status: GoalStatus.noData,
        start: start,
        current: current,
        target: target,
        fraction: 0,
        timeFraction: time,
      );
    }
    final gaining = target > start;
    final reached = start == target ? (current - target).abs() < 0.05 : (gaining ? current >= target : current <= target);
    final distance = (target - start).abs();
    final moved = gaining ? current - start : start - current;
    final fraction = reached
        ? 1.0
        : (distance == 0 ? 0.0 : (moved / distance).clamp(0.0, 1.0));

    GoalStatus status;
    if (reached) {
      status = GoalStatus.reached;
    } else if (fraction >= time + tolerance) {
      status = GoalStatus.ahead;
    } else if (fraction >= time - tolerance) {
      status = GoalStatus.onTrack;
    } else {
      status = GoalStatus.behind;
    }
    return MetricProgress(
      status: status,
      start: start,
      current: current,
      target: target,
      fraction: fraction,
      timeFraction: time,
    );
  }

  static double _timeFraction(DateTime start, DateTime event, DateTime now) {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(event.year, event.month, event.day);
    final n = DateTime(now.year, now.month, now.day);
    final total = e.difference(s).inDays;
    if (total <= 0) return 1;
    return (n.difference(s).inDays / total).clamp(0.0, 1.0);
  }
}

/// First and latest numeric value of [key] in a measurement history (oldest first).
({double? first, double? latest}) historyEnds(
  List<Map<String, dynamic>> history,
  String key,
) {
  double? first;
  double? latest;
  for (final e in history) {
    final v = double.tryParse('${e[key] ?? ''}');
    if (v == null) continue;
    first ??= v;
    latest = v;
  }
  return (first: first, latest: latest);
}
