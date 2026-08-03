import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

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
    } catch (_) {}
    return {};
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
      print('=== USER DATA: $data');
      print('=== CHALLENGE DURATION RAW: ${data['challengeDuration']}');
      user = data;
      challengeDuration =
          int.tryParse(data['challengeDuration']?.toString() ?? '100') ?? 100;
      print('=== CHALLENGE DURATION PARSED: $challengeDuration');
    } catch (e) {
      print('=== USER LOAD ERROR: $e');
    }

    isLoading = false;
    notifyListeners();
  }
}
