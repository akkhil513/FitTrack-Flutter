import 'dart:convert';

import 'package:fittrack/services/progress_stats.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> log(
  String date, {
  Map<String, bool>? checklist,
  List<Map<String, dynamic>>? exercises,
  String session = '',
}) => {
  'date': date,
  'session': session,
  'checklist': checklist == null ? ' ' : jsonEncode(checklist),
  'exercises': exercises == null ? ' ' : jsonEncode(exercises),
};

void main() {
  final today = DateTime(2026, 11, 14);

  test('checklist completion is the share of ticked items', () {
    expect(
      ProgressStats.checklistCompletion(jsonEncode({'a': true, 'b': false})),
      0.5,
    );
    expect(ProgressStats.checklistCompletion(' '), 0);
    expect(ProgressStats.checklistCompletion('not json'), 0);
  });

  test('completed sets only counts sets marked done', () {
    final raw = jsonEncode([
      {
        'name': 'Bench',
        'sets': [
          {'weight': '60', 'reps': '8', 'done': true},
          {'weight': '60', 'reps': '8', 'done': false},
        ],
      },
    ]);
    expect(ProgressStats.completedSets(raw), 1);
  });

  test('streak counts consecutive active days ending today', () {
    final logs = [
      log('2026-11-14', checklist: {'a': true, 'b': true}),
      log('2026-11-13', checklist: {'a': true, 'b': false}),
      log('2026-11-12', checklist: {'a': true, 'b': true}),
      log('2026-11-10', checklist: {'a': true, 'b': true}),
    ];
    expect(ProgressStats.fromLogs(logs, today).streak, 3);
  });

  test('today not done yet does not break the streak', () {
    final logs = [
      log('2026-11-13', checklist: {'a': true}),
      log('2026-11-12', checklist: {'a': true}),
    ];
    expect(ProgressStats.fromLogs(logs, today).streak, 2);
  });

  test('a missed day resets the streak', () {
    final logs = [
      log('2026-11-14', checklist: {'a': true}),
      log('2026-11-12', checklist: {'a': true}),
    ];
    expect(ProgressStats.fromLogs(logs, today).streak, 1);
  });

  test('last7 is oldest first and ends today', () {
    final stats = ProgressStats.fromLogs([
      log('2026-11-14', checklist: {'a': true, 'b': false}),
      log('2026-11-08', checklist: {'a': true}),
    ], today);
    expect(stats.last7.length, 7);
    // Window is 2026-11-08 .. 2026-11-14.
    expect(stats.last7.first, 1); // 11-08 fully done
    expect(stats.last7[1], 0); // 11-09 no log
    expect(stats.last7.last, 0.5); // 11-14 half done
  });

  test('workouts and recent sessions come from logged sets', () {
    final stats = ProgressStats.fromLogs([
      log(
        '2026-11-13',
        session: 'Push A',
        exercises: [
          {
            'name': 'Bench',
            'sets': [
              {'weight': '60', 'reps': '8', 'done': true},
            ],
          },
        ],
      ),
      log('2026-11-12', checklist: {'a': true}),
    ], today);
    expect(stats.workouts, 1);
    expect(stats.recent.single.session, 'Push A');
    expect(stats.recent.single.sets, 1);
  });
}
