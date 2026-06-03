import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../crew_constants.dart';
import '../error_helper.dart';
import '../notifications_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _selectedRole = CrewConstants.roleHelper;
  bool _loading = false;

  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (!_emailRegex.hasMatch(email)) {
      AppFeedback.showError(context, 'Please enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      AppFeedback.showError(
          context, 'Password must be at least 6 characters.');
      return;
    }
    if (password != confirm) {
      AppFeedback.showError(context, 'Passwords do not match.');
      return;
    }

    setState(() => _loading = true);

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );
      if (!mounted) return;

      final user = response.user;
      if (user == null) {
        setState(() => _loading = false);
        AppFeedback.showError(
            context, 'Sign up failed. Please try again.');
        return;
      }

      // Insert user record with role. If THIS fails we must NOT navigate.
      try {
        await Supabase.instance.client.from('users').upsert({
          'id': user.id,
          'email': email,
          'role': _selectedRole,
        });
        if (!mounted) return;
      } catch (e) {
        if (!mounted) return;
        AppFeedback.showError(context, e);
        setState(() => _loading = false);
        return;
      }

      // Best-effort token sync; must never block or fail the auth flow.
      try {
        await NotificationsService.syncTokenForCurrentUser();
      } catch (_) {}
      if (!mounted) return;

      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, e);
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),

                // Header
                const Text(
                  'CREW',
                  style: TextStyle(
                    color: Color(0xFFFF6B35),
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Create your account',
                  style: TextStyle(
                    color: Color(0xFF8896b0),
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),

                const SizedBox(height: 36),

                // Role selector
                const Text(
                  'I AM A',
                  style: TextStyle(
                    color: Color(0xFF8896b0),
                    fontSize: 11,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(
                            () => _selectedRole = CrewConstants.roleHelper),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _selectedRole == CrewConstants.roleHelper
                                ? const Color(0xFFFF6B35)
                                : const Color(0xFF111827),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _selectedRole == CrewConstants.roleHelper
                                  ? const Color(0xFFFF6B35)
                                  : const Color(0xFF1e2d45),
                            ),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                '👷',
                                style: TextStyle(fontSize: 24),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'HELPER',
                                style: TextStyle(
                                  color:
                                      _selectedRole == CrewConstants.roleHelper
                                          ? Colors.white
                                          : const Color(0xFF8896b0),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                ),
                              ),
                              Text(
                                'Looking for work',
                                style: TextStyle(
                                  color:
                                      _selectedRole == CrewConstants.roleHelper
                                          ? Colors.white70
                                          : const Color(0xFF8896b0),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(
                            () => _selectedRole = CrewConstants.roleJourneyman),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _selectedRole == CrewConstants.roleJourneyman
                                ? const Color(0xFFFF6B35)
                                : const Color(0xFF111827),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color:
                                  _selectedRole == CrewConstants.roleJourneyman
                                      ? const Color(0xFFFF6B35)
                                      : const Color(0xFF1e2d45),
                            ),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                '🔧',
                                style: TextStyle(fontSize: 24),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'JOURNEYMAN',
                                style: TextStyle(
                                  color: _selectedRole ==
                                          CrewConstants.roleJourneyman
                                      ? Colors.white
                                      : const Color(0xFF8896b0),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                ),
                              ),
                              Text(
                                'Hiring helpers',
                                style: TextStyle(
                                  color: _selectedRole ==
                                          CrewConstants.roleJourneyman
                                      ? Colors.white70
                                      : const Color(0xFF8896b0),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Email
                const Text(
                  'EMAIL',
                  style: TextStyle(
                    color: Color(0xFF8896b0),
                    fontSize: 11,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  maxLength: 100,
                  style: const TextStyle(color: Color(0xFFF0F4FF)),
                  decoration: const InputDecoration(
                    hintText: 'you@example.com',
                    counterText: '',
                  ),
                ),

                const SizedBox(height: 20),

                // Password
                const Text(
                  'PASSWORD',
                  style: TextStyle(
                    color: Color(0xFF8896b0),
                    fontSize: 11,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  maxLength: 50,
                  style: const TextStyle(color: Color(0xFFF0F4FF)),
                  decoration: const InputDecoration(
                    hintText: '••••••••',
                    counterText: '',
                  ),
                ),

                const SizedBox(height: 20),

                // Confirm Password
                const Text(
                  'CONFIRM PASSWORD',
                  style: TextStyle(
                    color: Color(0xFF8896b0),
                    fontSize: 11,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  maxLength: 50,
                  style: const TextStyle(color: Color(0xFFF0F4FF)),
                  decoration: const InputDecoration(
                    hintText: '••••••••',
                    counterText: '',
                  ),
                  onSubmitted: (_) {
                    if (!_loading) _register();
                  },
                ),

                const SizedBox(height: 24),

                // Sign Up button
                ElevatedButton(
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('CREATE ACCOUNT'),
                ),

                const SizedBox(height: 20),

                // Login link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(color: Color(0xFF8896b0)),
                    ),
                    GestureDetector(
                      onTap: () =>
                          Navigator.pushReplacementNamed(context, '/login'),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          color: Color(0xFFFF6B35),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
