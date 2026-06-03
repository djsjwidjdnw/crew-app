import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'notifications_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://jatngydbjplpowvkqtiv.supabase.co',
    anonKey: 'sb_publishable_phblhYkdvoKyr2FG8R2fcA_A4j0G9Vp',
  );

  // Best-effort: build the push-notification infrastructure. Safe on web
  // (no-op) and before Firebase is configured (degrades quietly).
  try {
    await NotificationsService.initialize();
  } catch (_) {
    // Never block app startup on notifications setup.
  }

  runApp(const CrewApp());
}

final supabase = Supabase.instance.client;

class CrewApp extends StatefulWidget {
  const CrewApp({super.key});

  @override
  State<CrewApp> createState() => _CrewAppState();
}

class _CrewAppState extends State<CrewApp> {
  /// Global navigator so the auth listener can redirect from anywhere.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    // Global session-expiry handling: when the user is signed out (including a
    // failed token refresh / expired session), bounce to /login and clear the
    // back stack so authed screens are never left visible.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedOut) {
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crew',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF6B35),
          secondary: Color(0xFF1E3A5F),
          surface: Color(0xFF111827),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Color(0xFFF0F4FF),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF111827),
          foregroundColor: Color(0xFFF0F4FF),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: Color(0xFFFF6B35),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF6B35),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0A0E1A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFF1e2d45)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFF1e2d45)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFFFF6B35)),
          ),
          labelStyle: const TextStyle(color: Color(0xFF8896b0)),
          hintStyle: const TextStyle(color: Color(0xFF8896b0)),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF111827),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF1e2d45)),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF111827),
          selectedItemColor: Color(0xFFFF6B35),
          unselectedItemColor: Color(0xFF8896b0),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: Color(0xFFF0F4FF),
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
          headlineMedium: TextStyle(
            color: Color(0xFFF0F4FF),
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: TextStyle(
            color: Color(0xFFF0F4FF),
            fontSize: 16,
          ),
          bodyMedium: TextStyle(
            color: Color(0xFF8896b0),
            fontSize: 14,
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => SplashScreen(),
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/home': (context) => HomeScreen(),
      },
    );
  }
}
