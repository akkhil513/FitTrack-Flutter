import 'dart:convert';

import 'package:fittrack/services/reminder_calendar.dart';
import 'package:fittrack/services/supplement_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

SupplementReminder r({
  String id = 'a1',
  int hour = 8,
  int minute = 0,
  Set<int>? days,
  bool enabled = true,
  bool repeat = false,
  String label = 'Vitamin D3',
}) =>
    SupplementReminder(
      id: id,
      hour: hour,
      minute: minute,
      label: label,
      days: days,
      enabled: enabled,
      repeat: repeat,
    );

int count(String text, String needle) => needle.allMatches(text).length;

void main() {
  // Monday 2026-11-16, 10:00.
  final now = DateTime(2026, 11, 16, 10);

  test('is a well-formed calendar with CRLF line endings', () {
    final ics = buildReminderCalendar([r()], now: now);
    expect(ics.startsWith('BEGIN:VCALENDAR\r\n'), isTrue);
    expect(ics.endsWith('END:VCALENDAR\r\n'), isTrue);
    expect(ics.contains('VERSION:2.0'), isTrue);
    expect(RegExp(r'(?<!\r)\n').hasMatch(ics), isFalse); // no bare LF
    expect(count(ics, 'BEGIN:VEVENT'), count(ics, 'END:VEVENT'));
  });

  test('one event per enabled reminder; disabled ones are left out', () {
    final ics = buildReminderCalendar([
      r(id: 'a'),
      r(id: 'b', enabled: false),
      r(id: 'c'),
    ], now: now);
    expect(count(ics, 'BEGIN:VEVENT'), 2);
    expect(ics.contains('UID:fittrack-b@fittrack'), isFalse);
  });

  test('no reminders still gives a valid empty calendar', () {
    final ics = buildReminderCalendar([], now: now);
    expect(count(ics, 'BEGIN:VEVENT'), 0);
    expect(ics.contains('END:VCALENDAR'), isTrue);
  });

  test('UIDs are stable so re-importing can update events', () {
    final a = buildReminderCalendar([r(id: 'x1')], now: now);
    final b = buildReminderCalendar([r(id: 'x1', hour: 9)], now: now.add(const Duration(days: 3)));
    expect(a.contains('UID:fittrack-x1@fittrack'), isTrue);
    expect(b.contains('UID:fittrack-x1@fittrack'), isTrue);
  });

  test('every-day reminders repeat daily; others weekly with sorted days', () {
    expect(buildReminderCalendar([r()], now: now).contains('RRULE:FREQ=DAILY'), isTrue);
    final weekly = buildReminderCalendar([r(days: {5, 1, 3})], now: now);
    expect(weekly.contains('RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR'), isTrue);
  });

  test('start is the first selected day, as a floating local time', () {
    // Monday, 08:00 already passed but the series still starts today (the rule skips the past).
    expect(buildReminderCalendar([r(hour: 8)], now: now), contains('DTSTART:20261116T080000\r\n'));
    // Wednesday only: starts on the 18th.
    expect(buildReminderCalendar([r(days: {3})], now: now), contains('DTSTART:20261118T080000\r\n'));
    // Event runs 5 minutes, even across midnight.
    final late = buildReminderCalendar([r(hour: 23, minute: 58)], now: now);
    expect(late, contains('DTSTART:20261116T235800'));
    expect(late, contains('DTEND:20261117T000300'));
    expect(late.contains('TZID'), isFalse);
  });

  test('alerts: one at the time, a second when "remind again" is on', () {
    final single = buildReminderCalendar([r()], now: now);
    expect(count(single, 'BEGIN:VALARM'), 1);
    expect(single, contains('TRIGGER:PT0S'));
    final twice = buildReminderCalendar([r(repeat: true)], now: now);
    expect(count(twice, 'BEGIN:VALARM'), 2);
    expect(twice, contains('TRIGGER:PT10M'));
  });

  test('commas and semicolons in names are escaped', () {
    final ics = buildReminderCalendar([r(label: 'Vitamin D3, Omega-3; zinc')], now: now);
    expect(ics, contains(r'SUMMARY:Take Vitamin D3\, Omega-3\; zinc'));
  });

  test('a name cannot inject calendar lines', () {
    final ics = buildReminderCalendar(
      [r(label: 'Iron\r\nBEGIN:VEVENT\r\nSUMMARY:evil')],
      now: now,
    );
    // Control characters are removed, so the text stays inside the one SUMMARY line.
    expect(RegExp(r'^BEGIN:VEVENT', multiLine: true).allMatches(ics).length, 1);
    expect(RegExp(r'^SUMMARY:evil', multiLine: true).hasMatch(ics), isFalse);
  });

  test('long lines are folded to 75 octets without splitting characters', () {
    final ics = buildReminderCalendar(
      [r(label: 'Ashwagandha ${'é' * 80}')],
      now: now,
    );
    for (final line in ics.split('\r\n')) {
      expect(utf8.encode(line).length <= 75, isTrue, reason: line);
    }
    // Unfolding restores the full text.
    expect(ics.replaceAll('\r\n ', '').contains('é' * 80), isTrue);
  });

  test('supplements read "Take X"; other kinds keep their own label', () {
    final ics = buildReminderCalendar([
      r(id: 'a', label: 'Zinc'),
      SupplementReminder(
        id: 'b',
        hour: 17,
        minute: 30,
        label: 'Workout time',
        kind: ReminderKind.workout,
      ),
    ], now: now);
    expect(ics.contains('SUMMARY:Take Zinc'), isTrue);
    expect(ics.contains('SUMMARY:Workout time'), isTrue);
    expect(ics.contains('SUMMARY:Take Workout time'), isFalse);
  });
}
