import 'package:flutter/material.dart';
import '../providers/theme_provider.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    required this.theme,
    required this.child,
    this.motifs = const [
      Icons.fitness_center,
      Icons.directions_run,
      Icons.self_improvement,
    ],
    this.backgroundImageUrl,
    this.backgroundAssetPath,
    this.showMotifs = true,
    this.imageOverlayOpacity = 0.45,
  });

  final ThemeProvider theme;
  final Widget child;
  final List<IconData> motifs;
  final String? backgroundImageUrl;
  final String? backgroundAssetPath;
  final bool showMotifs;
  final double imageOverlayOpacity;

  @override
  Widget build(BuildContext context) {
    final gradientColors = theme.isDark
        ? const [Color(0xFF06121A), Color(0xFF0A1D28), Color(0xFF102A22)]
        : const [Color(0xFFE6F7FF), Color(0xFFEAFBF1), Color(0xFFF7FFE8)];

    final orbAColor = theme.isDark
        ? const Color(0xFF0EA5E9).withValues(alpha: 0.22)
        : const Color(0xFF22D3EE).withValues(alpha: 0.25);
    final orbBColor = theme.isDark
        ? const Color(0xFF22C55E).withValues(alpha: 0.18)
        : const Color(0xFFA3E635).withValues(alpha: 0.20);
    final orbCColor = theme.isDark
        ? const Color(0xFFFDE047).withValues(alpha: 0.12)
        : const Color(0xFF38BDF8).withValues(alpha: 0.15);

    return SizedBox.expand(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (backgroundAssetPath != null)
              Image.asset(backgroundAssetPath!, fit: BoxFit.cover),
            if (backgroundImageUrl != null)
              Image.network(
                backgroundImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: imageOverlayOpacity),
              ),
            ),
            Positioned(
              top: -80,
              right: -40,
              child: _Orb(size: 220, color: orbAColor),
            ),
            Positioned(
              top: 180,
              left: -70,
              child: _Orb(size: 190, color: orbBColor),
            ),
            Positioned(
              bottom: -65,
              right: 30,
              child: _Orb(size: 170, color: orbCColor),
            ),
            if (showMotifs)
              Positioned(
                top: 120,
                right: 18,
                child: _MotifIcon(
                  icon: motifs[0 % motifs.length],
                  size: 96,
                  color: theme.isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFF0F172A).withValues(alpha: 0.07),
                  angle: -0.25,
                ),
              ),
            if (showMotifs)
              Positioned(
                top: 300,
                left: 12,
                child: _MotifIcon(
                  icon: motifs[1 % motifs.length],
                  size: 84,
                  color: theme.isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : const Color(0xFF0F172A).withValues(alpha: 0.06),
                  angle: 0.18,
                ),
              ),
            if (showMotifs)
              Positioned(
                bottom: 110,
                right: 42,
                child: _MotifIcon(
                  icon: motifs[2 % motifs.length],
                  size: 108,
                  color: theme.isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : const Color(0xFF0F172A).withValues(alpha: 0.06),
                  angle: -0.12,
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _MotifIcon extends StatelessWidget {
  const _MotifIcon({
    required this.icon,
    required this.size,
    required this.color,
    required this.angle,
  });

  final IconData icon;
  final double size;
  final Color color;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.rotate(
        angle: angle,
        child: Icon(icon, size: size, color: color),
      ),
    );
  }
}
