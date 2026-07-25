import 'package:flutter/material.dart';
import '../widgets/input_decoration.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'dashboard/dashboard_screen.dart';

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
  bool _loading = false;
  String _error = '';
  String _step = 'register';

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
      await AuthService.confirmSignUp(
        email: _emailController.text.trim(),
        code: _codeController.text.trim(),
      );

      await AuthService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      await ApiService.createUser(
        userId: AuthService.userId!,
        firstName: _nameController.text.split(' ').first,
        lastName: _nameController.text.split(' ').length > 1
            ? _nameController.text.split(' ').last
            : '',
        email: _emailController.text.trim(),
        username: _emailController.text.split('@').first,
      );

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _step == 'register'
              ? _buildRegisterForm()
              : _buildVerifyForm(),
        ),
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(
            Icons.arrow_back_ios,
            color: Color(0xFF555555),
            size: 20,
          ),
        ),
        const SizedBox(height: 24),
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
          'JOIN THE\nCHALLENGE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 42,
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Create your free account',
          style: TextStyle(color: Color(0xFF555555), fontSize: 14),
        ),
        const SizedBox(height: 32),

        const Text(
          'FULL NAME',
          style: TextStyle(
            color: Color(0xFF555555),
            fontSize: 11,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white),
          decoration: fitTrackInput('Akhil Gollapalli'),
        ),
        const SizedBox(height: 16),

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
          decoration: fitTrackInput('Min 8 chars, 1 uppercase, 1 number'),
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
              backgroundColor: const Color(0xFFE8FF47),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _loading
                ? const CircularProgressIndicator(color: Colors.black)
                : const Text(
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
            const Text(
              'Already have an account? ',
              style: TextStyle(color: Color(0xFF555555), fontSize: 14),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Text(
                'Sign in',
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
    );
  }

  Widget _buildVerifyForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _step = 'register'),
          child: const Icon(
            Icons.arrow_back_ios,
            color: Color(0xFF555555),
            size: 20,
          ),
        ),
        const SizedBox(height: 24),
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
          'CHECK YOUR\nEMAIL',
          style: TextStyle(
            color: Colors.white,
            fontSize: 42,
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a 6-digit code to ${_emailController.text}',
          style: const TextStyle(color: Color(0xFF555555), fontSize: 14),
        ),
        const SizedBox(height: 32),

        const Text(
          'VERIFICATION CODE',
          style: TextStyle(
            color: Color(0xFF555555),
            fontSize: 11,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            letterSpacing: 12,
          ),
          decoration: fitTrackInput('123456').copyWith(counterText: ''),
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
              backgroundColor: const Color(0xFFE8FF47),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _loading
                ? const CircularProgressIndicator(color: Colors.black)
                : const Text(
                    'VERIFY →',
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
