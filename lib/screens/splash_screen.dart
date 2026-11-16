import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/plan_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/user_provider.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';
import 'dashboard/dashboard_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _ticks = 21;
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    // One pass, no loop: the strip fills once, then we move on.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _progress = CurvedAnimation(parent: _controller, curve: Motion.ease);
    _controller.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  /// Restore a saved session while the splash plays, then pick the first screen.
  Future<void> _boot() async {
    final started = DateTime.now();
    final auth = context.read<AuthProvider>();
    final user = context.read<UserProvider>();
    final plan = context.read<PlanProvider>();

    var restored = false;
    try {
      restored = await auth.restoreSession();
      if (restored) {
        await user.loadUser(auth.userId!);
        await plan.loadPlan(auth.userId!);
      }
    } catch (_) {
      restored = false;
    }

    const minimum = Duration(milliseconds: 1800);
    final elapsed = DateTime.now().difference(started);
    if (elapsed < minimum) await Future.delayed(minimum - elapsed);
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            restored ? const DashboardScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: theme.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'FitTrack',
              style: ftText(theme, size: 32, weight: FontWeight.w600),
            ),
            const SizedBox(height: Sp.x5),
            SizedBox(
              width: 168,
              height: 20,
              child: AnimatedBuilder(
                animation: _progress,
                builder: (context, _) {
                  final p = _progress.value;
                  return CustomPaint(
                    painter: TickStripPainter(
                      total: _ticks,
                      done: (p * _ticks).floor(),
                      today: 0,
                      accent: theme.accent,
                      track: theme.textTertiary.withValues(alpha: 0.3),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
