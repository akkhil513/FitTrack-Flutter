import 'package:fittrack/services/week_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a recap', () {
    final r = WeekReport.parse(
      '{"week":2,"sessions":4,"changes":[{"name":"Squat","weight":"102.5","action":"INCREASE"},'
      '{"name":"Bench","weight":"60","action":"HOLD"}]}',
    )!;
    expect(r.week, 2);
    expect(r.sessions, 4);
    expect(r.changes, hasLength(2));
    expect(r.increases, 1);
    expect(r.changes.first.increased, isTrue);
    expect(r.sessionsLabel, '4 sessions logged');
  });

  test('labels', () {
    expect(WeekReport.parse('{"week":1,"sessions":1,"changes":[]}')!.sessionsLabel, '1 session logged');
    expect(WeekReport.parse('{"week":1,"sessions":0,"changes":[]}')!.sessionsLabel, 'No sessions logged');
  });

  test('bad input gives null and bad changes are skipped', () {
    expect(WeekReport.parse(null), isNull);
    expect(WeekReport.parse(' '), isNull);
    expect(WeekReport.parse('{oops'), isNull);
    expect(WeekReport.parse('[1]'), isNull);
    expect(WeekReport.parse('{"week":"x","sessions":1}'), isNull);
    final r = WeekReport.parse(
      '{"week":2,"sessions":1,"changes":[1,{"name":"","weight":"5"},{"name":"A"},{"name":"B","weight":"5"}]}',
    )!;
    expect(r.changes.map((c) => c.name), ['B']);
  });
}
