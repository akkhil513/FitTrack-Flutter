import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class UserProvider extends ChangeNotifier {
  Map<String, dynamic>? user;
  bool isLoading = false;

  String get firstName => user?['firstName'] ?? '';
  String get lastName => user?['lastName'] ?? '';
  String get fullName => '$firstName $lastName'.trim();
  String get username => user?['username'] ?? '';
  String get email => user?['email'] ?? '';
  String get startDate => user?['startDate'] ?? '';

  int get dayNumber {
    if (startDate.isEmpty) return 1;
    final start = DateTime.parse(startDate);
    final diff = DateTime.now().difference(start).inDays + 1;
    return diff.clamp(1, 100);
  }

  int get daysLeft => (100 - dayNumber).clamp(0, 100);
  double get progress => dayNumber / 100;

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

  Future<void> loadUser(String userId) async {
    isLoading = true;
    notifyListeners();

    try {
      user = await ApiService.getUser(userId);
    } catch (_) {}

    isLoading = false;
    notifyListeners();
  }
}
