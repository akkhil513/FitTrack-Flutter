import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../providers/plan_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_background.dart';
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
      emailOrUsername: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (auth.error.isEmpty && auth.isLoggedIn && mounted) {
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
    final theme = context.watch<ThemeProvider>();
    final foregroundPrimary = Colors.white;
    final foregroundSecondary = Colors.white.withValues(alpha: 0.9);
    final foregroundMuted = theme.isDark
        ? Colors.white.withValues(alpha: 0.68)
        : const Color(0xFF374151).withValues(alpha: 0.9);
    final brandColor = theme.isDark ? theme.accent : const Color(0xFFE8FF47);

    return Scaffold(
      body: AppBackground(
        theme: theme,
        backgroundAssetPath: 'assets/images/login_bg_mobile.jpg',
        showMotifs: false,
        imageOverlayOpacity: theme.isDark ? 0.42 : 0.62,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'FITTRACK',
                      style: TextStyle(
                        color: brandColor,
                        fontSize: 14,
                        letterSpacing: 4,
                        shadows: const [
                          Shadow(
                            color: Color(0xAA000000),
                            blurRadius: 8,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => context.read<ThemeProvider>().toggleTheme(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.surface2,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: theme.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              theme.isDark ? Icons.dark_mode : Icons.light_mode,
                              size: 16,
                              color: theme.accent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              theme.isDark ? 'DARK' : 'LIGHT',
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'WELCOME\nBACK',
                  style: TextStyle(
                    color: foregroundPrimary,
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                    shadows: const [
                      Shadow(
                        color: Color(0xB3000000),
                        blurRadius: 12,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to your 100-day challenge',
                  style: TextStyle(
                    color: foregroundSecondary,
                    fontSize: 14,
                    shadows: const [
                      Shadow(
                        color: Color(0x99000000),
                        blurRadius: 8,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.isDark
                        ? Colors.black.withValues(alpha: 0.30)
                        : Colors.white.withValues(alpha: 0.58),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'EMAIL OR USERNAME',
                          style: const TextStyle(
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
                          decoration: fitTrackInput('email or username', theme),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'PASSWORD',
                          style: TextStyle(
                            color: foregroundMuted,
                            fontSize: 11,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          style: TextStyle(color: theme.textPrimary),
                          decoration: fitTrackInput('••••••••', theme),
                          onSubmitted: (_) => _login(),
                        ),
                        if (auth.error.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            auth.error,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: auth.isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.accent,
                              foregroundColor: theme.accentText,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: auth.isLoading
                                ? CircularProgressIndicator(
                                    color: theme.accentText,
                                  )
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
                            Text(
                              'No account? ',
                              style: TextStyle(
                                color: foregroundSecondary,
                                fontSize: 14,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              ),
                              child: Text(
                                'Sign up',
                                style: TextStyle(
                                  color: theme.accent,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
