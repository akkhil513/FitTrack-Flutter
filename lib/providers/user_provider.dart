import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/goals.dart';
import '../services/supplement_reminder.dart';
import '../services/week_math.dart';

class UserProvider extends ChangeNotifier {
  Map<String, dynamic>? user;
  bool isLoading = false;
  int challengeDuration = 100; // default 100 days

  String get firstName => user?['firstName'] ?? '';
  String get lastName => user?['lastName'] ?? '';
  String get fullName => '$firstName $lastName'.trim();
  String get username => user?['username'] ?? '';
  String get email => user?['email'] ?? '';
  String get startDate => user?['startDate']?.toString() ?? '';

  /// Calendar challenge week (Monday to Sunday), independent of which week's plan is stored.
  int get calendarWeek {
    try {
      return challengeWeek(DateTime.parse(startDate), DateTime.now());
    } catch (_) {
      return 1;
    }
  }

  int get dayNumber {
    if (startDate.isEmpty) return 1;
    try {
      final start = DateTime.parse(startDate);
      final today = DateTime.now();

      // If start date is in the future - challenge has not started yet.
      if (start.isAfter(today)) return 0;

      final diff = today.difference(start).inDays + 1;
      return diff.clamp(1, challengeDuration);
    } catch (_) {
      return 1;
    }
  }

  int get daysLeft =>
      (challengeDuration - dayNumber).clamp(0, challengeDuration);
  double get progress => dayNumber / challengeDuration;

  Map<String, dynamic> get measurements {
    try {
      final raw = user?['measurements'];
      if (raw != null &&
          raw.toString().trim().isNotEmpty &&
          raw.toString().trim() != ' ') {
        return Map<String, dynamic>.from(jsonDecode(raw.toString()));
      }
    } catch (_) {
      // Keep the last known state; the UI shows its empty state.
    }
    return {};
  }

  /// Dated snapshots of weight/waist/chest, oldest first.
  List<Map<String, dynamic>> get measurementHistory {
    try {
      final raw = user?['measurementHistory'];
      if (raw != null &&
          raw.toString().trim().isNotEmpty &&
          raw.toString().trim() != ' ') {
        final list = jsonDecode(raw.toString()) as List;
        return list
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (_) {
      // Unreadable history is treated as empty.
    }
    return [];
  }

  /// Saves today's measurements: updates the current values and records one
  /// history entry per day (re-saving the same day replaces it).
  Future<void> saveMeasurements(
    String userId, {
    double? weight,
    double? waist,
    double? chest,
  }) async {
    final current = Map<String, dynamic>.from(measurements);
    if (weight != null) current['weight'] = weight;
    if (waist != null) current['waist'] = waist;
    if (chest != null) current['chest'] = chest;

    final today = DateTime.now().toIso8601String().split('T')[0];
    final history = measurementHistory
        .where((e) => e['date']?.toString() != today)
        .toList()
      ..add({'date': today, ...current});
    history.sort(
      (a, b) => a['date'].toString().compareTo(b['date'].toString()),
    );

    final currentJson = jsonEncode(current);
    final historyJson = jsonEncode(history);
    await ApiService.saveMeasurements(
      userId,
      measurements: currentJson,
      measurementHistory: historyJson,
    );

    user ??= {};
    user!['measurements'] = currentJson;
    user!['measurementHistory'] = historyJson;
    notifyListeners();
  }

  /// Supplement reminders, soonest time of day first.
  List<SupplementReminder> get supplementReminders =>
      SupplementReminder.parseList(user?['supplementReminders']);

  /// Saves the full list. The local copy changes only after the server accepted it, so a failed
  /// save leaves the screen showing what is actually stored (the error is rethrown).
  Future<void> saveSupplementReminders(
    String userId,
    List<SupplementReminder> reminders,
  ) async {
    final sorted = [...reminders]..sort(SupplementReminder.compareByTime);
    final json = sorted.map((r) => r.toJson()).toList();
    await ApiService.saveSupplementReminders(userId, json);
    user ??= {};
    user!['supplementReminders'] = jsonEncode(json);
    notifyListeners();
  }

  Goals get goals => Goals.parse(user?['goals']);

  /// The date the countdown runs to: the user's event date, or the last challenge day.
  DateTime? get goalDate {
    DateTime? start;
    try {
      start = startDate.isEmpty ? null : DateTime.parse(startDate);
    } catch (_) {
      start = null;
    }
    return Goals.effectiveEventDate(goals, start, challengeDuration);
  }

  /// Saves goals. The local copy changes only after the server accepted them.
  Future<void> saveGoals(String userId, Goals goals) async {
    final json = jsonEncode(goals.toJson());
    await ApiService.saveGoals(userId, json);
    user ??= {};
    user!['goals'] = json;
    notifyListeners();
  }

  void setChallengeDuration(int duration) {
    challengeDuration = duration;
    user ??= {};
    user!['challengeDuration'] = duration.toString();
    user!['startDate'] = DateTime.now().toIso8601String().split('T')[0];
    notifyListeners();
  }

  Future<void> loadUser(String userId) async {
    isLoading = true;
    notifyListeners();

    try {
      final data = await ApiService.getUser(userId);
      user = data;
      challengeDuration =
          int.tryParse(data['challengeDuration']?.toString() ?? '100') ?? 100;
    } catch (_) {
      // Keep the last known state; the UI shows its empty state.
    }

    isLoading = false;
    notifyListeners();
  }
}
