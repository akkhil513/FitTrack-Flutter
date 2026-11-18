import 'dart:convert';

import 'package:fittrack/services/supplement_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

SupplementReminder r({
  int hour = 8,
  int minute = 0,
  Set<int>? days,
  bool enabled = true,
  String label = 'Vitamin D3',
}) =>
    SupplementReminder(
      id: 'a1',
      hour: hour,
      minute: minute,
      label: label,
      days: days,
      enabled: enabled,
    );

void main() {
  group('JSON', () {
    test('round trips through the server format', () {
      final original = r(hour: 21, minute: 5, days: {5, 1, 3});
      final json = original.toJson();
      expect(json['time'], '21:05');
      expect(json['days'], [1, 3, 5]);
      final back = SupplementReminder.tryFromJson(json)!;
      expect(back.hour, 21);
      expect(back.minute, 5);
      expect(back.days, {1, 3, 5});
      expect(back.label, 'Vitamin D3');
    });

    test('parseList tolerates blank, garbage and bad entries', () {
      expect(SupplementReminder.parseList(null), isEmpty);
      expect(SupplementReminder.parseList(' '), isEmpty);
      expect(SupplementReminder.parseList('not json'), isEmpty);
      expect(SupplementReminder.parseList('{"a":1}'), isEmpty);
      final list = SupplementReminder.parseList(jsonEncode([
        r(hour: 22).toJson(),
        {'id': 'bad', 'time': '25:00', 'label': 'x', 'days': [1]},
        {'id': 'bad2', 'time': '08:00', 'label': 'x', 'days': []},
        r(hour: 7).toJson()..['id'] = 'a2',
      ]));
      expect(list.map((e) => e.hour), [7, 22]); // sorted, bad ones skipped
    });
  });

  group('labels', () {
    test('12-hour clock', () {
      expect(r(hour: 0, minute: 5).clock, '12:05');
      expect(r(hour: 0).meridiem, 'AM');
      expect(r(hour: 12).clock, '12:00');
      expect(r(hour: 12).meridiem, 'PM');
      expect(r(hour: 13, minute: 30).clock, '1:30');
      expect(r(hour: 23).meridiem, 'PM');
    });

    test('days label', () {
      expect(r().daysLabel, 'Every day');
      expect(r(days: {1, 2, 3, 4, 5}).daysLabel, 'Weekdays');
      expect(r(days: {6, 7}).daysLabel, 'Weekends');
      expect(r(days: {5, 1, 3}).daysLabel, 'Mon Wed Fri');
    });
  });

  group('next occurrence', () {
    // Monday 2026-11-16, 10:00.
    final now = DateTime(2026, 11, 16, 10);

    test('later today when the time is still ahead', () {
      expect(r(hour: 13).nextAfter(now), DateTime(2026, 11, 16, 13));
    });

    test('tomorrow when today has passed', () {
      expect(r(hour: 8).nextAfter(now), DateTime(2026, 11, 17, 8));
    });

    test('exactly now counts as passed', () {
      expect(r(hour: 10).nextAfter(now), DateTime(2026, 11, 17, 10));
    });

    test('skips days that are not selected', () {
      expect(r(hour: 8, days: {3}).nextAfter(now), DateTime(2026, 11, 18, 8));
      expect(r(hour: 13, days: {1}).nextAfter(now), DateTime(2026, 11, 16, 13));
      expect(r(hour: 8, days: {1}).nextAfter(now), DateTime(2026, 11, 23, 8));
    });

    test('disabled reminders never fire', () {
      expect(r(enabled: false).nextAfter(now), isNull);
    });

    test('nextOf picks the soonest', () {
      final list = [r(hour: 22), r(hour: 13), r(hour: 8)];
      expect(SupplementReminder.nextOf(list, now), DateTime(2026, 11, 16, 13));
      expect(SupplementReminder.nextOf([], now), isNull);
    });

    test('describeNext', () {
      expect(describeNext(DateTime(2026, 11, 16, 13), now), '1:00 PM today');
      expect(describeNext(DateTime(2026, 11, 17, 8), now), '8:00 AM tomorrow');
      expect(describeNext(DateTime(2026, 11, 19, 8), now), 'Thu 8:00 AM');
    });
  });

  test('ids are unique and match the server pattern', () {
    final ids = List.generate(200, (_) => SupplementReminder.newId()).toSet();
    expect(ids.length, 200);
    expect(ids.every((id) => RegExp(r'^[A-Za-z0-9_-]{1,40}$').hasMatch(id)), isTrue);
  });

  test('kind round-trips and unknown or missing kinds fall back to supplement', () {
    final water = SupplementReminder(
      id: 'w1',
      hour: 10,
      minute: 0,
      label: 'Drink water',
      kind: ReminderKind.water,
    );
    expect(water.toJson()['kind'], 'water');
    expect(SupplementReminder.tryFromJson(water.toJson())!.kind, ReminderKind.water);

    final legacy = {'id': 'a', 'time': '08:00', 'label': 'Zinc', 'days': [1]};
    expect(SupplementReminder.tryFromJson(legacy)!.kind, ReminderKind.supplement);
    expect(
      SupplementReminder.tryFromJson({...legacy, 'kind': 'nonsense'})!.kind,
      ReminderKind.supplement,
    );
  });
}
