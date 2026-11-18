import 'dart:convert';

import 'package:fittrack/services/missed_day.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Tuesday 2026-11-17, so yesterday is Monday 2026-11-16.
  final today = DateTime(2026, 11, 17, 9);
  final start = DateTime(2026, 11, 16);

  final training = <String, dynamic>{
    'Monday': {
      'session': 'Push',
      'isRestDay': false,
      'exercises': [
        {'name': 'Bench', 'sets': 3},
      ],
    },
    'Sunday': {'session': 'Rest', 'isRestDay': true, 'exercises': []},
  };

  Map<String, dynamic> log({bool done = false, String skipped = ' '}) => {
        'date': '2026-11-16',
        'skipped': skipped,
        'exercises': jsonEncode([
          {
            'name': 'Bench',
            'sets': [
              {'weight': '60', 'reps': '8', 'done': done},
            ],
          },
        ]),
      };

  MissedDay? find({List<dynamic> logs = const [], DateTime? s, DateTime? now, Map<String, dynamic>? plan}) =>
      findMissedDay(
        training: plan ?? training,
        logs: logs,
        today: now ?? today,
        challengeStart: s ?? start,
      );

  test('yesterday had a session and no log: missed', () {
    final m = find()!;
    expect(m.dayName, 'Monday');
    expect(m.session, 'Push');
    expect(m.date, '2026-11-16');
  });

  test('a log with no completed sets is still missed', () {
    expect(find(logs: [log()]), isNotNull);
  });

  test('a completed set means it was not missed', () {
    expect(find(logs: [log(done: true)]), isNull);
  });

  test('a skipped day is not reported again', () {
    expect(find(logs: [log(skipped: 'true')]), isNull);
  });

  test('rest days and days with no session are never missed', () {
    expect(find(now: DateTime(2026, 11, 23)), isNull); // yesterday = Sunday (rest)
    expect(find(now: DateTime(2026, 11, 18)), isNull); // yesterday = Tuesday, not in plan
  });

  test('nothing before the challenge started', () {
    expect(find(s: DateTime(2026, 11, 17)), isNull);
  });

  test('no plan, no result', () {
    expect(findMissedDay(training: null, logs: const [], today: today, challengeStart: start), isNull);
  });
}
