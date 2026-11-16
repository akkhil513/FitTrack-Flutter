import 'package:flutter/material.dart';
import '../providers/theme_provider.dart';
import '../theme/tokens.dart';

InputDecoration fitTrackInput(String hint, ThemeProvider theme) {
  OutlineInputBorder outline(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(Rd.control),
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: theme.textTertiary, fontSize: 15),
    filled: true,
    fillColor: theme.surface2,
    isDense: true,
    constraints: const BoxConstraints(minHeight: 48),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: Sp.x4,
      vertical: Sp.x3,
    ),
    border: outline(theme.border),
    enabledBorder: outline(theme.border),
    focusedBorder: outline(theme.accent),
  );
}
