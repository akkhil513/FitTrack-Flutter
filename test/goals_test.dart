import 'package:fittrack/services/goals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Goals parsing', () {
    test('blank, junk and wrong types mean no goals', () {
      expect(Goals.parse(null).isEmpty, isTrue);
      expect(Goals.parse(' ').isEmpty, isTrue);
      expect(Goals.parse('{not json').isEmpty, isTrue);
      expect(Goals.parse('[1]').isEmpty, isTrue);
      final g = Goals.parse('{"targetWeight":"70","eventDate":"soon"}');
      expect(g.targetWeight, isNull);
      expect(g.eventDate, isNull);
    });

    test('round trip', () {
      final g = Goals(
        targetWeight: 75.5,
        targetWaist: 82,
        eventDate: DateTime(2026, 12, 30),
      );
      final back = Goals.parse(
        '{"targetWeight":75.5,"targetWaist":82.0,"eventDate":"2026-12-30"}',
      );
      expect(back.targetWeight, g.targetWeight);
      expect(back.targetWaist, g.targetWaist);
      expect(back.eventDate, g.eventDate);
      expect(g.toJson()['eventDate'], '2026-12-30');
    });
  });

  group('event date and countdown', () {
    test('defaults to the last day of the challenge', () {
      final d = Goals.effectiveEventDate(Goals.empty, DateTime(2026, 11, 16), 45);
      expect(d, DateTime(2026, 12, 30));
    });

    test('an explicit event date wins', () {
      final d = Goals.effectiveEventDate(
        Goals(eventDate: DateTime(2027, 1, 5)),
        DateTime(2026, 11, 16),
        45,
      );
      expect(d, DateTime(2027, 1, 5));
    });

    test('no start date and no event means no date', () {
      expect(Goals.effectiveEventDate(Goals.empty, null, 45), isNull);
    });

    test('daysUntil counts whole days and goes negative after the event', () {
      final event = DateTime(2026, 12, 30);
      expect(Goals.daysUntil(event, DateTime(2026, 11, 16, 23, 59)), 44);
      expect(Goals.daysUntil(event, DateTime(2026, 12, 30, 8)), 0);
      expect(Goals.daysUntil(event, DateTime(2027, 1, 2)), -3);
    });
  });

  group('MetricProgress', () {
    final start = DateTime(2026, 11, 16);
    final event = DateTime(2026, 12, 26); // 40 days
    MetricProgress at(double current, int day, {double from = 90, double to = 80}) =>
        MetricProgress.compute(
          start: from,
          current: current,
          target: to,
          challengeStart: start,
          event: event,
          now: DateTime(2026, 11, 16 + day),
        );

    test('no measurements means no data', () {
      final p = MetricProgress.compute(
        start: null,
        current: null,
        target: 80,
        challengeStart: start,
        event: event,
        now: start,
      );
      expect(p.status, GoalStatus.noData);
    });

    test('losing weight: on track, ahead, behind', () {
      // Halfway through time (day 20) should be about 85.
      expect(at(85, 20).status, GoalStatus.onTrack);
      expect(at(83, 20).status, GoalStatus.ahead);
      expect(at(89, 20).status, GoalStatus.behind);
    });

    test('losing weight: reached when at or below target', () {
      expect(at(80, 10).status, GoalStatus.reached);
      expect(at(79, 10).status, GoalStatus.reached);
      expect(at(79, 10).fraction, 1);
    });

    test('gaining weight uses the opposite direction', () {
      expect(at(65, 20, from: 60, to: 70).status, GoalStatus.onTrack);
      expect(at(57, 20, from: 60, to: 70).status, GoalStatus.behind);
      expect(at(71, 20, from: 60, to: 70).status, GoalStatus.reached);
    });

    test('moving the wrong way is behind with zero progress', () {
      final p = at(92, 20);
      expect(p.status, GoalStatus.behind);
      expect(p.fraction, 0);
    });

    test('the very start is on track', () {
      expect(at(90, 0).status, GoalStatus.onTrack);
    });

    test('an event date on or before the start does not divide by zero', () {
      final p = MetricProgress.compute(
        start: 90,
        current: 89,
        target: 80,
        challengeStart: start,
        event: start,
        now: start,
      );
      expect(p.timeFraction, 1);
      expect(p.status, GoalStatus.behind);
    });

    test('start equal to target is reached only when current matches', () {
      final p = at(80, 5, from: 80, to: 80);
      expect(p.status, GoalStatus.reached);
    });

    test('remaining distance', () {
      expect(at(85, 20).remaining, 5);
    });
  });

  test('historyEnds finds first and latest numeric values', () {
    final ends = historyEnds([
      {'date': '2026-11-01', 'weight': 'x'},
      {'date': '2026-11-02', 'weight': 90},
      {'date': '2026-11-09', 'weight': '88.5'},
      {'date': '2026-11-10'},
    ], 'weight');
    expect(ends.first, 90);
    expect(ends.latest, 88.5);
    expect(historyEnds([], 'weight').first, isNull);
  });
}
