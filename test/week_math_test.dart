import 'package:fittrack/services/week_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 11, 11); // Wednesday

  test('week 1 is the calendar week containing the start date', () {
    expect(challengeWeek(start, DateTime(2026, 11, 11)), 1);
    expect(challengeWeek(start, DateTime(2026, 11, 15)), 1);
  });

  test('a new week begins every Monday', () {
    expect(challengeWeek(start, DateTime(2026, 11, 16)), 2);
    expect(challengeWeek(start, DateTime(2026, 11, 23)), 3);
  });

  test('never below week 1 for a future start', () {
    expect(challengeWeek(start, DateTime(2026, 10, 1)), 1);
  });
}
