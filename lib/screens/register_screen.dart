import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../widgets/input_decoration.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'onboarding_screen.dart';
import '../providers/theme_provider.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  String _step = 'register';
  String _error = '';
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _register() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() => _error = 'Fill in all fields');
      return;
    }
    if (_passwordController.text.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      await AuthService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _step = 'verify';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _verify() async {
    if (_codeController.text.isEmpty) {
      setState(() => _error = 'Enter the verification code');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      // Confirm signup
      await AuthService.confirmSignUp(
        email: _emailController.text.trim(),
        code: _codeController.text.trim(),
      );

      // Sign in
      await AuthService.signIn(
        emailOrUsername: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Create user in DynamoDB
      await ApiService.createUser(
        userId: AuthService.userId!,
        firstName: _nameController.text.split(' ').first,
        lastName: _nameController.text.split(' ').length > 1
            ? _nameController.text.split(' ').last
            : '',
        email: _emailController.text.trim(),
        username: _emailController.text.split('@').first,
      );

      // Update providers
      if (mounted) {
        await context.read<UserProvider>().loadUser(AuthService.userId!);
        if (!mounted) return;

        // Go to onboarding, not the dashboard
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x2, Sp.x6, Sp.x6),
          child: _step == 'register'
              ? _buildRegisterForm(theme)
              : _buildVerifyForm(theme),
        ),
      ),
    );
  }

  Widget _back(ThemeProvider theme, VoidCallback onTap) {
    return IconButton(
      tooltip: 'Back',
      onPressed: onTap,
      icon: Icon(Icons.arrow_back, size: 20, color: theme.textSecondary),
    );
  }

  Widget _header(ThemeProvider theme, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(left: Sp.x2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: Sp.x8),
          Text(title, style: ftText(theme, size: 28, weight: FontWeight.w600)),
          const SizedBox(height: Sp.x2),
          Text(subtitle, style: ftText(theme, size: 14, color: theme.textSecondary)),
          const SizedBox(height: Sp.x8),
        ],
      ),
    );
  }

  Widget _errorText(ThemeProvider theme) {
    if (_error.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Sp.x3),
      child: Text(_error, style: ftText(theme, size: 13, color: theme.negative)),
    );
  }

  Widget _buildRegisterForm(ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _back(theme, () => Navigator.pop(context)),
        _header(theme, 'Create account', 'Next, you will set up your plan.'),
        Padding(
          padding: const EdgeInsets.only(left: Sp.x2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FtLabel('Full name'),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                style: ftText(theme, size: 15),
                decoration: fitTrackInput('Alex Johnson', theme),
              ),
              const SizedBox(height: Sp.x4),
              const FtLabel('Email'),
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
                decoration: fitTrackInput('8+ characters, 1 uppercase, 1 number', theme),
              ),
              _errorText(theme),
              const SizedBox(height: Sp.x8),
              FtButton(
                label: 'Create account',
                loading: _loading,
                onPressed: _loading ? null : _register,
              ),
              const SizedBox(height: Sp.x5),
              Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.pop(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Sp.x2),
                    child: Text.rich(
                      TextSpan(
                        text: 'Have an account? ',
                        style: ftText(theme, size: 14, color: theme.textSecondary),
                        children: [
                          TextSpan(
                            text: 'Sign in',
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
      ],
    );
  }

  Widget _buildVerifyForm(ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _back(theme, () => setState(() => _step = 'register')),
        _header(
          theme,
          'Check your email',
          'We sent a 6-digit code to ${_emailController.text}.',
        ),
        Padding(
          padding: const EdgeInsets.only(left: Sp.x2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FtLabel('Verification code'),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: ftText(theme, size: 24, weight: FontWeight.w500, tabular: true)
                    .copyWith(letterSpacing: 8),
                decoration: fitTrackInput('123456', theme).copyWith(counterText: ''),
              ),
              _errorText(theme),
              const SizedBox(height: Sp.x8),
              FtButton(
                label: 'Verify and continue',
                loading: _loading,
                onPressed: _loading ? null : _verify,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
