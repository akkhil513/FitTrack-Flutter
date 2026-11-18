import 'dart:convert';
import 'dart:io';

import 'package:fittrack/services/exercise_library.dart';
import 'package:fittrack/services/stretches.dart';
import 'package:flutter_test/flutter_test.dart';

ExerciseLibrary _lib() {
  final raw = File('assets/exercises.json').readAsStringSync();
  final list = (jsonDecode(raw) as List).whereType<Map<String, dynamic>>();
  return ExerciseLibrary([for (final j in list) LibraryExercise.fromJson(j)]);
}

void main() {
  final lib = _lib();

  test('the bundled dataset loads', () {
    expect(lib.all.length, greaterThan(800));
    expect(lib.all.first.imageUrls.first, startsWith('https://raw.githubusercontent.com/'));
  });

  test('common plan names find their exercise', () {
    expect(lib.match('Barbell Bench Press')?.name, contains('Bench Press'));
    expect(lib.match('Lat Pulldown')?.name.toLowerCase(), contains('pulldown'));
    expect(lib.match('Romanian Deadlift')?.name, 'Romanian Deadlift');
  });

  test('nonsense and look-alike names do not match', () {
    expect(lib.match('Zzzz Qqqq'), isNull);
    expect(nameSimilarity('Incline Dumbbell Press', 'Decline Dumbbell Press'), lessThan(ExerciseLibrary.matchThreshold));
  });

  test('search excludes stretches and finds by prefix', () {
    final hits = lib.search('bench');
    expect(hits, isNotEmpty);
    expect(hits.every((e) => e.category != 'stretching'), isTrue);
  });

  test('alternatives share the main muscle and exclude the exercise itself', () {
    final ex = lib.match('Barbell Bench Press')!;
    final alts = lib.alternatives(ex);
    expect(alts.length, lessThanOrEqualTo(3));
    expect(alts.every((e) => e.id != ex.id && e.primary.first == ex.primary.first), isTrue);
  });

  test('every curated stretch exists in the library', () {
    for (final s in ['Push Day', 'Pull Day', 'Leg Day', 'Upper Body', 'Full Body']) {
      for (final plan in [warmupFor(s), cooldownFor(s)]) {
        expect(plan.items.length, inInclusiveRange(4, 6));
        for (final item in plan.items) {
          expect(lib.byId(item.id), isNotNull, reason: item.id);
        }
      }
    }
  });

  test('session titles map to a body focus', () {
    expect(focusOf('Leg Day'), BodyFocus.legs);
    expect(focusOf('Back and Biceps'), BodyFocus.pull);
    expect(focusOf('Chest & Triceps'), BodyFocus.push);
    expect(focusOf('Active Recovery'), BodyFocus.general);
  });
}
