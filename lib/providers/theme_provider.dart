import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Design tokens. Dark: graphite neutrals with a volt accent. Light: warm
/// cream paper, ink text, terracotta accent and a serif display face.
class ThemeProvider extends ChangeNotifier {
  bool _isDark = true;

  bool get isDark => _isDark;

  void toggleTheme() {
    _isDark = !_isDark;
    notifyListeners();
  }

  // Surfaces
  Color get background =>
      _isDark ? const Color(0xFF141415) : const Color(0xFFF6F1E9);
  Color get surface =>
      _isDark ? const Color(0xFF19191B) : const Color(0xFFFFFFFF);
  Color get surface2 =>
      _isDark ? const Color(0xFF232325) : const Color(0xFFEFE8DC);
  // Hairline: primary text colour at 8%.
  Color get border =>
      _isDark ? const Color(0x14EDEDED) : const Color(0x1F1F1B16);

  /// Serif for large numerals and titles in light mode; null keeps the
  /// platform sans in dark mode. Georgia exists on iOS/macOS; Android falls
  /// back to its generic serif.
  String? get displayFont => _isDark ? null : 'Georgia';

  // Text roles
  Color get textPrimary =>
      _isDark ? const Color(0xFFEDEDED) : const Color(0xFF1F1B16);
  Color get textSecondary =>
      _isDark ? const Color(0xFFA1A1A6) : const Color(0xFF5C5348);
  Color get textTertiary =>
      _isDark ? const Color(0xFF85858B) : const Color(0xFF6B6154);

  // The single accent: used for "today", "done" and the primary action.
  Color get accent =>
      _isDark ? const Color(0xFFE8FF47) : const Color(0xFFB4472A);
  Color get accentLight => accent.withValues(alpha: 0.12);
  Color get accentText =>
      _isDark ? const Color(0xFF0F0F10) : const Color(0xFFFFFFFF);

  // Semantic colours, used for meaning only.
  Color get positive =>
      _isDark ? const Color(0xFF4CC38A) : const Color(0xFF1E7A4C);
  Color get negative =>
      _isDark ? const Color(0xFFE5484D) : const Color(0xFFDC2626);

  ThemeData get materialTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: _isDark ? Brightness.dark : Brightness.light,
    );
    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme(
        brightness: _isDark ? Brightness.dark : Brightness.light,
        primary: accent,
        onPrimary: accentText,
        secondary: accent,
        onSecondary: accentText,
        error: negative,
        onError: Colors.white,
        surface: surface,
        onSurface: textPrimary,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerColor: border,
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Rd.panel),
          side: BorderSide(color: border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surface2,
        contentTextStyle: TextStyle(color: textPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Rd.control),
          side: BorderSide(color: border),
        ),
      ),
    );
  }
}
