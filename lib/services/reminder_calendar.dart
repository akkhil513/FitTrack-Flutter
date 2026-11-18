import 'dart:convert';
import 'supplement_reminder.dart';

/// Builds an iCalendar (.ics) file with one repeating event per enabled reminder.
///
/// Why a calendar file: a web app cannot ring in the background, but the phone's Calendar can.
/// Each event has an alert at the reminder time (and optionally a second one a few minutes later).
///
/// Times are written as "floating" local times (no time zone), so they fire at the same wall-clock
/// time wherever the phone is. Event UIDs are stable per reminder so re-importing can update an
/// existing event instead of creating a duplicate (calendar apps differ in whether they do).
String buildReminderCalendar(
  List<SupplementReminder> reminders, {
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final stamp = _utc(current.toUtc());
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//FitTrack//Reminders//EN',
    'CALSCALE:GREGORIAN',
  ];

  for (final r in reminders.where((r) => r.enabled && r.days.isNotEmpty)) {
    final first = _firstOccurrence(r, current);
    final end = first.add(const Duration(minutes: 5));
    final label = _clean(r.label);
    final summary = reminderSummary(r.kind, label);

    lines
      ..add('BEGIN:VEVENT')
      ..add('UID:fittrack-${_clean(r.id)}@fittrack')
      ..add('DTSTAMP:$stamp')
      ..add('DTSTART:${_local(first)}')
      ..add('DTEND:${_local(end)}')
      ..add('RRULE:${_rule(r)}')
      ..add('SUMMARY:${_escape(summary)}')
      ..add('DESCRIPTION:${_escape('Reminder from FitTrack')}')
      ..add('TRANSP:TRANSPARENT')
      ..addAll(_alarm(summary, 'PT0S'));
    if (r.repeat) {
      lines.addAll(_alarm(summary, 'PT${SupplementReminder.repeatAfterMinutes}M'));
    }
    lines.add('END:VEVENT');
  }

  lines.add('END:VCALENDAR');
  return '${lines.map(_fold).join('\r\n')}\r\n';
}

/// Supplements read "Take Zinc"; other kinds already have a complete label ("Drink water").
String reminderSummary(ReminderKind kind, String label) =>
    kind == ReminderKind.supplement ? 'Take $label' : label;

List<String> _alarm(String description, String trigger) => [
      'BEGIN:VALARM',
      'ACTION:DISPLAY',
      'DESCRIPTION:${_escape(description)}',
      'TRIGGER:$trigger',
      'END:VALARM',
    ];

String _rule(SupplementReminder r) {
  if (r.days.length == 7) return 'FREQ=DAILY';
  const codes = {1: 'MO', 2: 'TU', 3: 'WE', 4: 'TH', 5: 'FR', 6: 'SA', 7: 'SU'};
  final days = (r.days.toList()..sort()).map((d) => codes[d]).join(',');
  return 'FREQ=WEEKLY;BYDAY=$days';
}

DateTime _firstOccurrence(SupplementReminder r, DateTime now) {
  for (var offset = 0; offset < 7; offset++) {
    final day = DateTime(now.year, now.month, now.day + offset);
    if (r.days.contains(day.weekday)) {
      return DateTime(day.year, day.month, day.day, r.hour, r.minute);
    }
  }
  return DateTime(now.year, now.month, now.day, r.hour, r.minute);
}

/// Removes control characters so a label can never start a new calendar line.
String _clean(String text) => text.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();

String _escape(String text) => _clean(text)
    .replaceAll('\\', '\\\\')
    .replaceAll(';', '\\;')
    .replaceAll(',', '\\,');

String _two(int v) => v.toString().padLeft(2, '0');

String _local(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}${_two(d.month)}${_two(d.day)}'
    'T${_two(d.hour)}${_two(d.minute)}${_two(d.second)}';

String _utc(DateTime d) => '${_local(d)}Z';

/// Lines longer than 75 octets must be folded (RFC 5545 section 3.1), never inside a character.
String _fold(String line) {
  if (utf8.encode(line).length <= 75) return line;
  final out = StringBuffer();
  var count = 0;
  for (final rune in line.runes) {
    final ch = String.fromCharCode(rune);
    final len = utf8.encode(ch).length;
    if (count + len > 75) {
      out.write('\r\n ');
      count = 1;
    }
    out.write(ch);
    count += len;
  }
  return out.toString();
}
