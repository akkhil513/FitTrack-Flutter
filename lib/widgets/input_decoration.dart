import 'package:flutter/material.dart';
import '../providers/theme_provider.dart';

InputDecoration fitTrackInput(String hint, ThemeProvider theme) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      color: theme.isDark ? const Color(0xFF333333) : const Color(0xFF999999),
    ),
    filled: true,
    fillColor: theme.surface2,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: theme.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: theme.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: theme.accent),
    ),
  );
}
