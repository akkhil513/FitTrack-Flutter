import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../widgets/input_decoration.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'onboarding_screen.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_background.dart';

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
      setState(() => _error = 'Please fill in all fields');
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
      // Show OTP screen
      setState(() {
        _loading = false;
        _step = 'verify';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _verify() async {
    if (_codeController.text.isEmpty) {
      setState(() => _error = 'Enter verification code');
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
        email: _emailController.text.trim(),
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

        // Go to onboarding — NOT dashboard
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          (route) => false,
        );
      }
    } catch (e) {
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
      body: AppBackground(
        theme: theme,
        motifs: const [
          Icons.emoji_people,
          Icons.directions_bike,
          Icons.fitness_center,
        ],
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _step == 'register'
                ? _buildRegisterForm(theme)
                : _buildVerifyForm(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterForm(ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(
            Icons.arrow_back_ios,
            color: theme.textSecondary,
            size: 20,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'FITTRACK',
          style: TextStyle(color: theme.accent, fontSize: 14, letterSpacing: 4),
        ),
        const SizedBox(height: 12),
        Text(
          'JOIN THE\nCHALLENGE',
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 42,
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Create your free account',
          style: TextStyle(color: theme.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 32),

        Text(
          'FULL NAME',
          style: TextStyle(
            color: theme.textSecondary,
            fontSize: 11,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          style: TextStyle(color: theme.textPrimary),
          decoration: fitTrackInput('Alex Johnson', theme),
        ),
        const SizedBox(height: 16),

        Text(
          'EMAIL',
          style: TextStyle(
            color: theme.textSecondary,
            fontSize: 11,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(color: theme.textPrimary),
          decoration: fitTrackInput('you@example.com', theme),
        ),
        const SizedBox(height: 16),

        Text(
          'PASSWORD',
          style: TextStyle(
            color: theme.textSecondary,
            fontSize: 11,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          obscureText: true,
          style: TextStyle(color: theme.textPrimary),
          decoration: fitTrackInput(
            'Min 8 chars, 1 uppercase, 1 number',
            theme,
          ),
        ),

        if (_error.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_error, style: const TextStyle(color: Colors.red, fontSize: 13)),
        ],

        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _register,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accent,
              foregroundColor: theme.accentText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _loading
                ? CircularProgressIndicator(color: theme.accentText)
                : Text(
                    'CREATE ACCOUNT →',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Already have an account? ',
              style: TextStyle(color: theme.textSecondary, fontSize: 14),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Text(
                'Sign in',
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
    );
  }

  Widget _buildVerifyForm(ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _step = 'register'),
          child: Icon(
            Icons.arrow_back_ios,
            color: theme.textSecondary,
            size: 20,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'FITTRACK',
          style: TextStyle(color: theme.accent, fontSize: 14, letterSpacing: 4),
        ),
        const SizedBox(height: 12),
        Text(
          'CHECK YOUR\nEMAIL',
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 42,
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a 6-digit code to ${_emailController.text}',
          style: TextStyle(color: theme.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 32),

        Text(
          'VERIFICATION CODE',
          style: TextStyle(
            color: theme.textSecondary,
            fontSize: 11,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 28,
            letterSpacing: 12,
          ),
          decoration: fitTrackInput('123456', theme).copyWith(counterText: ''),
        ),

        if (_error.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_error, style: const TextStyle(color: Colors.red, fontSize: 13)),
        ],

        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _verify,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accent,
              foregroundColor: theme.accentText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _loading
                ? CircularProgressIndicator(color: theme.accentText)
                : Text(
                    'VERIFY & CONTINUE →',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
