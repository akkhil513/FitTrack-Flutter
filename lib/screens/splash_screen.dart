import 'package:flutter/material.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('💪', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 16),
              const Text(
                'FITTRACK',
                style: TextStyle(
                  color: Color(0xFFE8FF47),
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '100 DAY CHALLENGE',
                style: TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 12,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  backgroundColor: Color(0xFF1A1A1A),
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE8FF47)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
