import 'dart:convert';

import 'package:fittrack/services/strength_stats.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> log(String date, List<Map<String, dynamic>> exercises) =>
    {'date': date, 'exercises': jsonEncode(exercises)};

Map<String, dynamic> ex(String name, List<List<Object>> sets) => {
      'name': name,
      'sets': [
        for (final s in sets) {'weight': s[0].toString(), 'reps': s[1].toString(), 'done': s[2]},
      ],
    };

void main() {
  test('Epley estimate, single rep, and rep cap', () {
    expect(StrengthStats.estimateOneRepMax(100, 1), 100);
    expect(StrengthStats.estimateOneRepMax(100, 10), closeTo(133.33, 0.01));
    expect(StrengthStats.estimateOneRepMax(100, 100), 200); // capped at 30 reps
    expect(StrengthStats.estimateOneRepMax(0, 5), 0);
    expect(StrengthStats.estimateOneRepMax(50, 0), 0);
  });

  test('parses numbers from messy text', () {
    expect(StrengthStats.parseNumber('62.5'), 62.5);
    expect(StrengthStats.parseNumber('60 kg'), 60);
    expect(StrengthStats.parseNumber('62,5'), 62.5);
    expect(StrengthStats.parseNumber('bodyweight'), isNull);
    expect(StrengthStats.parseNumber(null), isNull);
  });

  test('only completed sets with weight and reps count; best set per day wins', () {
    final h = StrengthStats.fromLogs([
      log('2026-11-16', [
        ex('Bench Press', [
          [60, 8, true],
          [70, 5, true],
          [100, 3, false], // not done
          ['', 10, true], // no weight
        ]),
      ]),
    ]);
    expect(h, hasLength(1));
    expect(h.first.sessions, hasLength(1));
    expect(h.first.latest.weight, 70); // 70x5 = 81.7 beats 60x8 = 76
    expect(h.first.latest.reps, 5);
  });

  test('names are grouped case-insensitively and sorted by recency', () {
    final h = StrengthStats.fromLogs([
      log('2026-11-10', [ex('squat', [[100, 5, true]])]),
      log('2026-11-12', [ex('Squat', [[105, 5, true]]), ex('Row', [[50, 8, true]])]),
      log('2026-11-14', [ex('Row', [[52, 8, true]])]),
    ]);
    expect(h.map((e) => e.name), ['Row', 'squat']);
    expect(h.last.sessions, hasLength(2));
  });

  test('a first session is not a PR; beating earlier sessions is', () {
    var h = StrengthStats.fromLogs([
      log('2026-11-10', [ex('Squat', [[100, 5, true]])]),
    ]);
    expect(h.first.latestIsPr, isFalse);

    h = StrengthStats.fromLogs([
      log('2026-11-10', [ex('Squat', [[100, 5, true]])]),
      log('2026-11-12', [ex('Squat', [[105, 5, true]])]),
    ]);
    expect(h.first.latestIsPr, isTrue);

    h = StrengthStats.fromLogs([
      log('2026-11-10', [ex('Squat', [[110, 5, true]])]),
      log('2026-11-12', [ex('Squat', [[100, 5, true]])]),
    ]);
    expect(h.first.latestIsPr, isFalse);
  });

  test('recentRecords keeps only fresh PRs', () {
    final h = StrengthStats.fromLogs([
      log('2026-10-01', [ex('Old', [[50, 5, true]])]),
      log('2026-10-05', [ex('Old', [[60, 5, true]])]),
      log('2026-11-10', [ex('New', [[50, 5, true]])]),
      log('2026-11-14', [ex('New', [[60, 5, true]])]),
    ]);
    final prs = StrengthStats.recentRecords(h, DateTime(2026, 11, 16));
    expect(prs.map((e) => e.name), ['New']);
  });

  test('bad data never throws', () {
    expect(StrengthStats.fromLogs([
      {'date': '2026-11-10', 'exercises': 'not json'},
      {'date': '2026-11-11', 'exercises': ' '},
      {'exercises': '[]'},
      'junk',
      log('2026-11-12', [
        {'name': 'X', 'sets': 'nope'},
        {'sets': []},
      ]),
    ]), isEmpty);
  });
}
