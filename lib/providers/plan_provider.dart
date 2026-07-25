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

    print('=== GENERATING PLAN for userId: ${payload['userId']}');

    try {
      final response = await ApiService.generatePlan(payload);
      print('=== PLAN GENERATE RESPONSE: $response');
      await _pollForPlan(payload['userId']);
    } catch (e) {
      print('=== PLAN GENERATE ERROR: $e');
      await _pollForPlan(payload['userId']);
    }
  }

  Future<void> _pollForPlan(String userId) async {
    print('=== POLLING FOR PLAN userId: $userId');
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(seconds: 5));
      try {
        final data = await ApiService.getPlan(userId);
        print(
          '=== POLL $i status: ${data['status']} strategy length: ${data['strategy']?.toString().length}',
        );
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
          } catch (e) {
            print('=== TRAINING PARSE ERROR: $e');
          }
          isLoading = false;
          notifyListeners();
          print('=== PLAN READY ✅');
          return;
        }
      } catch (e) {
        print('=== POLL ERROR: $e');
      }
    }
    isLoading = false;
    status = 'FAILED';
    notifyListeners();
    print('=== PLAN POLLING TIMED OUT');
  }
}
