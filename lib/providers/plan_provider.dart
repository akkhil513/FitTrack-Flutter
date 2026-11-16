import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PlanProvider extends ChangeNotifier {
  Map<String, dynamic>? plan;
  Map<String, dynamic>? training;
  bool isLoading = false;
  String status = '';
  int weekNumber = 1;

  bool get hasPlan => plan != null && status == 'READY';

  Future<void> loadPlan(String userId) async {
    isLoading = true;
    notifyListeners();

    try {
      final data = await ApiService.getPlan(userId);
      status = data['status']?.toString() ?? '';
      plan = data;
      weekNumber = int.tryParse(data['weekNumber']?.toString() ?? '1') ?? 1;

      try {
        var raw = data['training'];
        if (raw != null && raw.toString().trim().isNotEmpty) {
          raw = raw.toString().replaceAll(RegExp(r'^"|"$'), '');
          training = Map<String, dynamic>.from(jsonDecode(raw));
        }
      } catch (_) {
      // Keep the last known state; the UI shows its empty state.
    }
    } catch (_) {
      // Keep the last known state; the UI shows its empty state.
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> generatePlan(Map<String, dynamic> payload) async {
    isLoading = true;
    status = 'GENERATING';
    notifyListeners();

    try {
      await ApiService.generatePlan(payload);
      await _pollForPlan(payload['userId']);
    } catch (_) {
      await _pollForPlan(payload['userId']);
    }
  }

  Future<void> generateWeeklyPlan({
    required String userId,
    required int week,
    required String previousLogs,
  }) async {
    isLoading = true;
    status = 'GENERATING';
    notifyListeners();

    try {
      await ApiService.generateWeeklyPlan(
        userId: userId,
        weekNumber: week,
        previousLogs: previousLogs,
        userProfile: '',
      );
      await _pollForPlan(userId);
    } catch (e) {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _pollForPlan(String userId) async {
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(seconds: 5));
      try {
        final data = await ApiService.getPlan(userId);
        final s = data['status']?.toString() ?? '';
        if (s == 'READY' &&
            data['strategy'] != null &&
            data['strategy'].toString().trim().length > 5) {
          plan = data;
          status = 'READY';
          weekNumber = int.tryParse(data['weekNumber']?.toString() ?? '1') ?? 1;
          try {
            var raw = data['training'];
            if (raw != null && raw.toString().trim().isNotEmpty) {
              raw = raw.toString().replaceAll(RegExp(r'^"|"$'), '');
              training = Map<String, dynamic>.from(jsonDecode(raw));
            }
          } catch (_) {
      // Keep the last known state; the UI shows its empty state.
    }
          isLoading = false;
          notifyListeners();
          return;
        }
      } catch (_) {
      // Keep the last known state; the UI shows its empty state.
    }
    }
    isLoading = false;
    status = 'FAILED';
    notifyListeners();
  }
}
