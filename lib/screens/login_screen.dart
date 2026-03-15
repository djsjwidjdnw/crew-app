import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      await Supabase.instance.client.auth.signInWithPassword(email: _emailController.text.trim(), password: _passwordController.text);
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showForgotPassword() {
    final resetEmailController = TextEditingController(text: _emailController.text);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF111827),
      title: const Text('Reset Password', style: TextStyle(color: Color(0xFFF0F4FF), fontSize: 18)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Enter your email and we\'ll send you a link to reset your password.', style: TextStyle(color: Color(0xFF8896b0), fontSize: 13)),
        const SizedBox(height: 16),
        TextField(controller: resetEmailController, keyboardType: TextInputType.emailAddress, style: const TextStyle(color: Color(0xFFF0F4FF)), decoration: const InputDecoration(hintText: 'you@example.com')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: Color(0xFF8896b0)))),
        TextButton(onPressed: () async {
          final email = resetEmailController.text.trim();
          if (email.isEmpty) return;
          try {
            await Supabase.instance.client.auth.resetPasswordForEmail(email);
            Navigator.pop(ctx);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Password reset link sent to $email'), backgroundColor: const Color(0xFF22c55e)));
          } catch (e) {
            Navigator.pop(ctx);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error sending reset email. Check the email address.'), backgroundColor: Color(0xFFef4444)));
          }
        }, child: const Text('SEND RESET LINK', style: TextStyle(color: Color(0xFFFF6B35)))),
      ],
    ));
  }

  @override
  void dispose() { _emailController.dispose(); _passwordController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 48),
            const Text('CREW', style: TextStyle(color: Color(0xFFFF6B35), fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: 6)),
            const SizedBox(height: 4),
            const Text('Sign in to your account', style: TextStyle(color: Color(0xFF8896b0), fontSize: 14, letterSpacing: 1)),
            const SizedBox(height: 48),
            const Text('EMAIL', style: TextStyle(color: Color(0xFF8896b0), fontSize: 11, letterSpacing: 2)),
            const SizedBox(height: 8),
            TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, style: const TextStyle(color: Color(0xFFF0F4FF)), decoration: const InputDecoration(hintText: 'you@example.com')),
            const SizedBox(height: 20),
            const Text('PASSWORD', style: TextStyle(color: Color(0xFF8896b0), fontSize: 11, letterSpacing: 2)),
            const SizedBox(height: 8),
            TextField(controller: _passwordController, obscureText: true, style: const TextStyle(color: Color(0xFFF0F4FF)), decoration: const InputDecoration(hintText: '••••••••'), onSubmitted: (_) => _login()),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: _showForgotPassword,
                child: const Text('Forgot Password?', style: TextStyle(color: Color(0xFFFF6B35), fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null) Text(_error!, style: const TextStyle(color: Color(0xFFef4444), fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _loading ? null : _login, child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('SIGN IN')),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text("Don't have an account? ", style: TextStyle(color: Color(0xFF8896b0))),
              GestureDetector(onTap: () => Navigator.pushNamed(context, '/register'), child: const Text('Sign Up', style: TextStyle(color: Color(0xFFFF6B35), fontWeight: FontWeight.w600))),
            ]),
          ]),
        ),
      ),
    );
  }
}
