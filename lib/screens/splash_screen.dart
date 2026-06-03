import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../crew_constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    // Wait for Supabase to initialize.
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    try {
      final session = Supabase.instance.client.auth.currentSession;

      if (session != null) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (_) {
      // If anything goes wrong, fall back to login so the user can retry.
      // We cannot surface a snackbar before a Scaffold exists, so just route.
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CrewConstants.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: CrewConstants.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: CrewConstants.border, width: 1),
              ),
              child: const Center(
                child: Text(
                  'C',
                  style: TextStyle(
                    color: CrewConstants.primary,
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'CREW',
              style: TextStyle(
                color: CrewConstants.textPrimary,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'FIND YOUR CREW',
              style: TextStyle(
                color: CrewConstants.textSecondary,
                fontSize: 12,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: CrewConstants.primary,
                strokeWidth: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
