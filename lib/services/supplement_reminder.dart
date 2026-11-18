import 'dart:convert';
import 'dart:math';

/// What a reminder is for. The stored value is the [id] string; unknown values fall back to supplement.
class ReminderKind {
  const ReminderKind(this.id, this.title, this.defaultLabel, this.icon);

  final String id;
  final String title;
  final String defaultLabel;
  final String icon;

  static const supplement = ReminderKind('supplement', 'Supplement', '', 'S');
  static const workout = ReminderKind('workout', 'Workout', 'Workout time', 'W');
  static const meal = ReminderKind('meal', 'Meal', 'Meal', 'M');
  static const water = ReminderKind('water', 'Water', 'Drink water', 'H');
  static const weighIn = ReminderKind('weighin', 'Weigh-in', 'Weekly weigh-in', 'B');

  static const all = [supplement, workout, meal, water, weighIn];

  static ReminderKind byId(Object? id) =>
      all.firstWhere((k) => k.id == id, orElse: () => supplement);
}

/// One reminder: a time of day, what to take, and the weekdays it repeats.
///
/// Days use ISO numbering: 1 = Monday … 7 = Sunday (matches [DateTime.weekday]).
class SupplementReminder {
  SupplementReminder({
    required this.id,
    required this.hour,
    required this.minute,
    required this.label,
    Set<int>? days,
    this.enabled = true,
    this.repeat = false,
    this.kind = ReminderKind.supplement,
  }) : days = days ?? {1, 2, 3, 4, 5, 6, 7};

  static const maxReminders = 20;
  static const maxLabelLength = 80;
  static const repeatAfterMinutes = 10;

  final String id;
  final int hour;
  final int minute;
  final String label;
  final Set<int> days;
  final bool enabled;

  /// Ring a second time [repeatAfterMinutes] after the first alert.
  final bool repeat;
  final ReminderKind kind;

  static String newId() {
    final r = Random.secure();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return 'r${List.generate(10, (_) => chars[r.nextInt(chars.length)]).join()}';
  }

  SupplementReminder copyWith({
    int? hour,
    int? minute,
    String? label,
    Set<int>? days,
    bool? enabled,
    bool? repeat,
    ReminderKind? kind,
  }) =>
      SupplementReminder(
        id: id,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        label: label ?? this.label,
        days: days ?? this.days,
        enabled: enabled ?? this.enabled,
        repeat: repeat ?? this.repeat,
        kind: kind ?? this.kind,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': '${_two(hour)}:${_two(minute)}',
        'label': label,
        'kind': kind.id,
        'days': (days.toList()..sort()),
        'enabled': enabled,
        'repeat': repeat,
      };

  /// Returns null when the map is not a usable reminder.
  static SupplementReminder? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final time = raw['time'];
    final label = raw['label'];
    final days = raw['days'];
    if (id is! String || time is! String || label is! String || days is! List) {
      return null;
    }
    final m = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(time);
    if (m == null) return null;
    final dayList = days.whereType<int>().where((d) => d >= 1 && d <= 7).toSet();
    if (dayList.isEmpty) return null;
    return SupplementReminder(
      id: id,
      hour: int.parse(m.group(1)!),
      minute: int.parse(m.group(2)!),
      label: label,
      days: dayList,
      enabled: raw['enabled'] != false,
      repeat: raw['repeat'] == true,
      kind: ReminderKind.byId(raw['kind']),
    );
  }

  /// Parses the stored JSON string (blank means none). Bad entries are skipped.
  static List<SupplementReminder> parseList(Object? stored) {
    if (stored == null) return [];
    final text = stored.toString().trim();
    if (text.isEmpty) return [];
    try {
      final decoded = jsonDecode(text);
      if (decoded is! List) return [];
      final list = decoded
          .map(tryFromJson)
          .whereType<SupplementReminder>()
          .toList();
      list.sort(compareByTime);
      return list;
    } catch (_) {
      return [];
    }
  }

  static int compareByTime(SupplementReminder a, SupplementReminder b) {
    final byTime = (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute);
    return byTime != 0 ? byTime : a.label.compareTo(b.label);
  }

  /// "8:00" and "AM" for display.
  String get clock {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h:${_two(minute)}';
  }

  String get meridiem => hour < 12 ? 'AM' : 'PM';

  String get daysLabel {
    if (days.length == 7) return 'Every day';
    if (days.length == 5 && days.containsAll({1, 2, 3, 4, 5})) return 'Weekdays';
    if (days.length == 2 && days.containsAll({6, 7})) return 'Weekends';
    const names = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return (days.toList()..sort()).map((d) => names[d]).join(' ');
  }

  /// The next time this reminder fires strictly after [now], or null if disabled.
  DateTime? nextAfter(DateTime now) {
    if (!enabled || days.isEmpty) return null;
    for (var offset = 0; offset <= 7; offset++) {
      final day = DateTime(now.year, now.month, now.day + offset);
      if (!days.contains(day.weekday)) continue;
      final at = DateTime(day.year, day.month, day.day, hour, minute);
      if (at.isAfter(now)) return at;
    }
    return null;
  }

  static DateTime? nextOf(List<SupplementReminder> list, DateTime now) {
    DateTime? best;
    for (final r in list) {
      final n = r.nextAfter(now);
      if (n != null && (best == null || n.isBefore(best))) best = n;
    }
    return best;
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}

/// "1:00 PM today", "8:00 AM tomorrow" or "Wed 8:00 AM".
String describeNext(DateTime next, DateTime now) {
  final r = SupplementReminder(
    id: 'x',
    hour: next.hour,
    minute: next.minute,
    label: '',
  );
  final time = '${r.clock} ${r.meridiem}';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(next.year, next.month, next.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return '$time today';
  if (diff == 1) return '$time tomorrow';
  const names = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${names[next.weekday]} $time';
}
