import 'package:fittrack/services/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _session(String name) => {
      'session': name,
      'isRestDay': false,
      'exercises': [
        {'name': 'Bench Press'},
      ],
    };

final _training = <String, dynamic>{
  'Monday': _session('Push'),
  'Tuesday': _session('Pull'),
  'Wednesday': _session('Legs'),
  'Thursday': _session('Push'),
  'Friday': _session('Pull'),
  'Saturday': {'session': 'Active Recovery', 'isRestDay': true, 'exercises': []},
  'Sunday': {'session': 'Rest', 'isRestDay': true, 'exercises': []},
};

const _done = '[{"name":"Bench","sets":[{"weight":"60","reps":"5","done":true}]}]';

Map<String, String> _log(String date, {String planned = '', String rest = '', String ex = _done}) =>
    {'date': date, 'plannedDay': planned, 'rest': rest, 'exercises': ex, 'skipped': ''};

// Week of Mon 2026-11-16.
DateTime _d(int day) => DateTime(2026, 11, day);

void main() {
  test('trainingDays skips rest and recovery days', () {
    expect(trainingDays(_training), ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']);
  });

  test('with no logs each day does its own session', () {
    expect(suggestedSession(training: _training, date: _d(17), logs: []), 'Tuesday');
    expect(suggestedSession(training: _training, date: _d(16), logs: []), 'Monday');
  });

  test('a rest day hands its session to the next day and the week slides', () {
    final logs = [_log('2026-11-16', rest: 'true', ex: ' ')];
    expect(suggestedSession(training: _training, date: _d(17), logs: logs), 'Monday');
    final logs2 = [...logs, _log('2026-11-17', planned: 'Monday')];
    expect(suggestedSession(training: _training, date: _d(18), logs: logs2), 'Tuesday');
  });

  test('the slide runs into Saturday and Sunday, and the extra is dropped after that', () {
    final logs = [
      _log('2026-11-16', rest: 'true', ex: ' '),
      _log('2026-11-17', planned: 'Monday'),
      _log('2026-11-18', planned: 'Tuesday'),
      _log('2026-11-19', planned: 'Wednesday'),
      _log('2026-11-20', planned: 'Thursday'),
    ];
    expect(suggestedSession(training: _training, date: _d(21), logs: logs), 'Friday');
    final withSat = [...logs, _log('2026-11-21', planned: 'Friday')];
    expect(suggestedSession(training: _training, date: _d(22), logs: withSat), isNull);
  });

  test('a plan rest day with nothing pending is a rest day', () {
    final logs = [
      for (var i = 0; i < 5; i++) _log('2026-11-${16 + i}'),
    ];
    expect(suggestedSession(training: _training, date: _d(21), logs: logs), isNull);
  });

  test('days before the challenge start do not use up sessions', () {
    expect(
      suggestedSession(training: _training, date: _d(17), logs: [], challengeStart: _d(17)),
      'Monday',
    );
  });

  test('openSessions lists what is left, ignoring the day being edited', () {
    final logs = [_log('2026-11-16'), _log('2026-11-17')];
    expect(openSessions(training: _training, date: _d(18), logs: logs), ['Wednesday', 'Thursday', 'Friday']);
    expect(openSessions(training: _training, date: _d(17), logs: logs), ['Tuesday', 'Wednesday', 'Thursday', 'Friday']);
  });

  test('a rest log or an empty log never counts as cleared', () {
    expect(logCleared(_log('2026-11-16', rest: 'true')), isFalse);
    expect(logCleared(_log('2026-11-16', ex: ' ')), isFalse);
    expect(logCleared({'skipped': 'true', 'exercises': ' '}), isTrue);
  });
}
