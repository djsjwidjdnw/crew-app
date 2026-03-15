import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _selectedRole = 'helper';
  bool _loading = false;
  String? _error;

  Future<void> _register() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response.user != null) {
        // Insert user record with role
        await Supabase.instance.client.from('users').upsert({
          'id': response.user!.id,
          'email': _emailController.text.trim(),
          'role': _selectedRole,
        });

        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
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
      body: SafeArea(
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
                      onTap: () => setState(() => _selectedRole = 'helper'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _selectedRole == 'helper'
                              ? const Color(0xFFFF6B35)
                              : const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _selectedRole == 'helper'
                                ? const Color(0xFFFF6B35)
                                : const Color(0xFF1e2d45),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '👷',
                              style: TextStyle(fontSize: 24),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'HELPER',
                              style: TextStyle(
                                color: _selectedRole == 'helper'
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
                                color: _selectedRole == 'helper'
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
                      onTap: () => setState(() => _selectedRole = 'journeyman'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _selectedRole == 'journeyman'
                              ? const Color(0xFFFF6B35)
                              : const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _selectedRole == 'journeyman'
                                ? const Color(0xFFFF6B35)
                                : const Color(0xFF1e2d45),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '🔧',
                              style: TextStyle(fontSize: 24),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'JOURNEYMAN',
                              style: TextStyle(
                                color: _selectedRole == 'journeyman'
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
                                color: _selectedRole == 'journeyman'
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
                style: const TextStyle(color: Color(0xFFF0F4FF)),
                decoration: const InputDecoration(hintText: 'you@example.com'),
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
                style: const TextStyle(color: Color(0xFFF0F4FF)),
                decoration: const InputDecoration(hintText: '••••••••'),
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
                style: const TextStyle(color: Color(0xFFF0F4FF)),
                decoration: const InputDecoration(hintText: '••••••••'),
              ),

              const SizedBox(height: 12),

              // Error
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFef4444),
                    fontSize: 13,
                  ),
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
                    onTap: () => Navigator.pushReplacementNamed(context, '/login'),
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
    );
  }
}