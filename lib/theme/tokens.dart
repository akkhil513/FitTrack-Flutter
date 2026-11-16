import 'package:flutter/animation.dart';

/// Spacing scale — every gap in the app comes from here (4px grid).
class Sp {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;
  static const double x10 = 40;
  static const double x12 = 48;
  static const double x16 = 64;
}

/// Corner radii. Nested radius = outer radius - padding.
class Rd {
  static const double chip = 8;
  static const double control = 10;
  static const double card = 14;
  static const double panel = 16;
}

/// One easing curve, two durations.
class Motion {
  static const Curve ease = Cubic(0.22, 1, 0.36, 1);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 300);
}
