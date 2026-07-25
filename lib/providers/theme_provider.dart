import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDark = true;

  bool get isDark => _isDark;

  void toggleTheme() {
    _isDark = !_isDark;
    notifyListeners();
  }

  Color get background =>
      _isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5);
  Color get surface => _isDark ? const Color(0xFF111111) : Colors.white;
  Color get surface2 =>
      _isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0);
  Color get border =>
      _isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);
  Color get textPrimary => _isDark ? Colors.white : const Color(0xFF1A1A1A);
  Color get textSecondary =>
      _isDark ? const Color(0xFF555555) : const Color(0xFF666666);

  // Accent changes based on theme
  Color get accent => _isDark ? const Color(0xFFE8FF47) : const Color(0xFF1A1A1A);
  // 0x22 alpha tint of the accent — alpha is the leading byte.
  Color get accentLight =>
      _isDark ? const Color(0x22E8FF47) : const Color(0x221A1A1A);
  Color get accentText => _isDark ? Colors.black : Colors.white;

  // Always yellow for header bar
  Color get headerYellow => const Color(0xFFE8FF47);
  Color get headerText => Colors.black;

  Color get green => const Color(0xFF4ADE80);
  Color get blue => const Color(0xFF47C8FF);
  Color get orange => const Color(0xFFFF6B35);
  Color get purple => const Color(0xFFA78BFA);
}
