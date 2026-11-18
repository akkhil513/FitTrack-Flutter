import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// One entry of the bundled free-exercise-db dataset (Unlicense, github.com/yuhonas/free-exercise-db).
class LibraryExercise {
  const LibraryExercise({
    required this.id,
    required this.name,
    required this.level,
    required this.equipment,
    required this.category,
    required this.primary,
    required this.secondary,
    required this.instructions,
    required this.images,
  });

  final String id;
  final String name;
  final String level;
  final String equipment;
  final String category;
  final List<String> primary;
  final List<String> secondary;
  final List<String> instructions;
  final List<String> images;

  static const _imageBase =
      'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/';

  /// Absolute URLs of the two demo frames, empty when the entry has no images.
  List<String> get imageUrls => [for (final i in images) '$_imageBase$i'];

  factory LibraryExercise.fromJson(Map<String, dynamic> j) {
    List<String> strings(Object? v) =>
        v is List ? [for (final x in v) x.toString()] : const <String>[];
    return LibraryExercise(
      id: j['id']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      level: j['level']?.toString() ?? '',
      equipment: j['equipment']?.toString() ?? '',
      category: j['category']?.toString() ?? '',
      primary: strings(j['primaryMuscles']),
      secondary: strings(j['secondaryMuscles']),
      instructions: strings(j['instructions']),
      images: strings(j['images']),
    );
  }
}

/// Words that carry no movement information ("Barbell Bench Press - Medium Grip").
const _fillerWords = {'medium', 'grip', 'the', 'a', 'with', 'and'};

/// Words that turn one movement into a different one. A match that differs by one of these is penalised.
const _variantWords = {
  'incline', 'decline', 'one', 'single', 'lying', 'rear', 'smith', 'reverse', 'sumo', 'stiff', 'behind',
  'kneeling', 'hanging', 'alternating', 'isolation', 'car', 'band', 'ring', 'upright', 'ball', 'chain',
  'bosu', 'stability', 'trap',
};

/// Lower-cased word tokens of [name] with a crude singular form, so "Curls" matches "Curl".
Set<String> exerciseTokens(String name) {
  final words = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .split(' ')
      .where((w) => w.isNotEmpty && !_fillerWords.contains(w));
  return {
    for (final w in words)
      if (w.length > 3 && w.endsWith('s') && !w.endsWith('ss')) w.substring(0, w.length - 1) else w,
  };
}

/// Similarity of two exercise names in 0..1. At least three quarters of [a]'s words must appear in [b]; then it
/// mixes containment with Jaccard overlap and penalises a difference in variant words, so "Lat Pulldown" matches
/// "Wide-Grip Lat Pulldown" but "Incline Dumbbell Press" does not match "Decline Dumbbell Press".
double nameSimilarity(String a, String b) {
  final ta = exerciseTokens(a);
  final tb = exerciseTokens(b);
  if (ta.isEmpty || tb.isEmpty) return 0;
  final inter = ta.intersection(tb).length;
  if (inter == 0) return 0;
  final containment = inter / ta.length;
  if (containment < 0.75) return 0;
  var score = 0.5 * containment + 0.5 * inter / ta.union(tb).length;
  final differing = ta.difference(tb).union(tb.difference(ta));
  if (differing.any(_variantWords.contains)) score *= 0.7;
  return score;
}

class ExerciseLibrary {
  ExerciseLibrary(this.all) : _byId = {for (final e in all) e.id: e};

  final List<LibraryExercise> all;
  final Map<String, LibraryExercise> _byId;

  /// Minimum [nameSimilarity] for a plan exercise to count as the same movement.
  static const matchThreshold = 0.65;

  static ExerciseLibrary? _cached;
  static Future<ExerciseLibrary>? _loading;

  /// The library once it has loaded, otherwise null. Never blocks.
  static ExerciseLibrary? get cached => _cached;

  static Future<ExerciseLibrary> load() {
    final done = _cached;
    if (done != null) return Future.value(done);
    return _loading ??= rootBundle.loadString('assets/exercises.json').then((raw) {
      final list = (jsonDecode(raw) as List).whereType<Map<String, dynamic>>();
      return _cached = ExerciseLibrary([for (final j in list) LibraryExercise.fromJson(j)]);
    });
  }

  LibraryExercise? byId(String id) => _byId[id];

  /// Best match for a plan or user-typed name, or null when nothing is similar enough to trust.
  LibraryExercise? match(String name) {
    LibraryExercise? best;
    var bestScore = 0.0;
    for (final e in all) {
      final s = nameSimilarity(name, e.name);
      if (s > bestScore || (s == bestScore && best != null && e.name.length < best.name.length)) {
        best = e;
        bestScore = s;
      }
    }
    return bestScore >= matchThreshold ? best : null;
  }

  /// Strength-style exercises whose name contains every word of [query], best first.
  List<LibraryExercise> search(String query, {int limit = 8}) {
    final q = exerciseTokens(query);
    if (q.isEmpty) return const [];
    final scored = <(double, LibraryExercise)>[];
    for (final e in all) {
      if (e.category == 'stretching') continue;
      final t = exerciseTokens(e.name);
      if (!q.every((w) => t.any((x) => x.startsWith(w)))) continue;
      scored.add((nameSimilarity(query, e.name), e));
    }
    scored.sort((a, b) {
      final c = b.$1.compareTo(a.$1);
      return c != 0 ? c : a.$2.name.length.compareTo(b.$2.name.length);
    });
    return [for (final s in scored.take(limit)) s.$2];
  }

  /// Up to [count] other exercises for the same main muscle and equipment, easiest-to-find first.
  List<LibraryExercise> alternatives(LibraryExercise ex, {int count = 3}) {
    if (ex.primary.isEmpty) return const [];
    final muscle = ex.primary.first;
    bool sameKind(LibraryExercise e) => e.category == ex.category || e.category == 'strength';
    final pool = all.where((e) =>
        e.id != ex.id &&
        e.category != 'stretching' &&
        e.category != 'cardio' &&
        sameKind(e) &&
        e.primary.isNotEmpty &&
        e.primary.first == muscle &&
        nameSimilarity(ex.name, e.name) < 0.8);
    final sameEquip = pool.where((e) => e.equipment == ex.equipment).toList();
    final others = pool.where((e) => e.equipment != ex.equipment).toList();
    int byName(LibraryExercise a, LibraryExercise b) => a.name.length.compareTo(b.name.length);
    sameEquip.sort(byName);
    others.sort(byName);
    // Prefer the same equipment, then at most one with other kit so the list is not all the same movement.
    return [...sameEquip.take(count), ...others].take(count).toList();
  }
}
