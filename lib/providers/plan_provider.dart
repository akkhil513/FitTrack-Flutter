import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PlanProvider extends ChangeNotifier {
  Map<String, dynamic>? plan;
  Map<String, dynamic>? training;
  bool isLoading = false;
  String status = '';

  bool get hasplan => plan != null && status == 'READY';

  Future<void> loadPlan(String userId) async {
    isLoading = true;
    notifyListeners();

    try {
      final data = await ApiService.getPlan(userId);
      status = data['status']?.toString() ?? '';
      plan = data;

      try {
        var raw = data['training'];
        if (raw != null && raw.toString().trim().isNotEmpty) {
          raw = raw.toString().replaceAll(RegExp(r'^"|"$'), '');
          training = Map<String, dynamic>.from(jsonDecode(raw));
        }
      } catch (_) {}
    } catch (_) {}

    isLoading = false;
    notifyListeners();
  }

  Future<void> generatePlan(Map<String, dynamic> payload) async {
    isLoading = true;
    status = 'GENERATING';
    notifyListeners();

    try {
      await ApiService.generatePlan(payload);
      // Poll for plan
      await _pollForPlan(payload['userId']);
    } catch (_) {
      await _pollForPlan(payload['userId']);
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
          try {
            var raw = data['training'];
            if (raw != null && raw.toString().trim().isNotEmpty) {
              raw = raw.toString().replaceAll(RegExp(r'^"|"$'), '');
              training = Map<String, dynamic>.from(jsonDecode(raw));
            }
          } catch (_) {}
          isLoading = false;
          notifyListeners();
          return;
        }
      } catch (_) {}
    }
    isLoading = false;
    status = 'FAILED';
    notifyListeners();
  }
}
