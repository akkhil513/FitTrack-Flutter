import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../providers/plan_provider.dart';
import '../widgets/input_decoration.dart';
import 'register_screen.dart';
import 'dashboard/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    final auth = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();
    final planProvider = context.read<PlanProvider>();

    await auth.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (auth.error.isEmpty && auth.isLoggedIn && mounted) {
      // Load user and plan data
      await userProvider.loadUser(auth.userId!);
      await planProvider.loadPlan(auth.userId!);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'FITTRACK',
                style: TextStyle(
                  color: Color(0xFFE8FF47),
                  fontSize: 14,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'WELCOME\nBACK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in to your 100-day challenge',
                style: TextStyle(color: Color(0xFF555555), fontSize: 14),
              ),
              const SizedBox(height: 24),

              const Text(
                'EMAIL',
                style: TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 11,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: fitTrackInput('you@example.com'),
              ),
              const SizedBox(height: 16),

              const Text(
                'PASSWORD',
                style: TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 11,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: fitTrackInput('••••••••'),
                onSubmitted: (_) => _login(),
              ),

              if (auth.error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  auth.error,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8FF47),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: auth.isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text(
                          'SIGN IN →',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'No account? ',
                    style: TextStyle(color: Color(0xFF555555), fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    ),
                    child: const Text(
                      'Sign up',
                      style: TextStyle(
                        color: Color(0xFFE8FF47),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
