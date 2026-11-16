import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../providers/plan_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/tokens.dart';
import '../widgets/input_decoration.dart';
import '../widgets/ui.dart';
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

  bool _busy = false;

  void _login() async {
    if (_busy) return;
    final auth = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();
    final planProvider = context.read<PlanProvider>();

    setState(() => _busy = true);
    try {
      await auth.signIn(
        emailOrUsername: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (auth.error.isEmpty && auth.isLoggedIn && mounted) {
        // Keep the spinner up while the profile and plan load.
        await userProvider.loadUser(auth.userId!);
        await planProvider.loadPlan(auth.userId!);
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
        return;
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Sp.x6, Sp.x2, Sp.x6, Sp.x6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'FitTrack',
                    style: ftText(theme, size: 16, weight: FontWeight.w600),
                  ),
                  IconButton(
                    tooltip: theme.isDark ? 'Switch to light' : 'Switch to dark',
                    onPressed: () => context.read<ThemeProvider>().toggleTheme(),
                    icon: Icon(
                      theme.isDark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                      size: 20,
                      color: theme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Sp.x16),
              Text(
                'Sign in',
                style: ftText(theme, size: 28, weight: FontWeight.w600),
              ),
              const SizedBox(height: Sp.x2),
              Text(
                'Continue your challenge.',
                style: ftText(theme, size: 14, color: theme.textSecondary),
              ),
              const SizedBox(height: Sp.x8),
              const FtLabel('Email or username'),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                style: ftText(theme, size: 15),
                decoration: fitTrackInput('you@example.com', theme),
              ),
              const SizedBox(height: Sp.x4),
              const FtLabel('Password'),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: ftText(theme, size: 15),
                decoration: fitTrackInput('Password', theme),
                onSubmitted: (_) => _login(),
              ),
              if (auth.error.isNotEmpty) ...[
                const SizedBox(height: Sp.x3),
                Text(
                  auth.error,
                  style: ftText(theme, size: 13, color: theme.negative),
                ),
              ],
              const SizedBox(height: Sp.x6),
              FtButton(
                label: 'Sign in',
                loading: _busy || auth.isLoading,
                onPressed: (_busy || auth.isLoading) ? null : _login,
              ),
              const SizedBox(height: Sp.x5),
              Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Sp.x2),
                    child: Text.rich(
                      TextSpan(
                        text: 'No account? ',
                        style: ftText(theme, size: 14, color: theme.textSecondary),
                        children: [
                          TextSpan(
                            text: 'Create one',
                            style: ftText(
                              theme,
                              size: 14,
                              weight: FontWeight.w500,
                              color: theme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
