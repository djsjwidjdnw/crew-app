import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'swipe_screen.dart';
import 'matches_screen.dart';
import 'profile_screen.dart';
import 'job_post_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String? _role;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _loading = false);
        return;
      }

      final res = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', userId)
          .maybeSingle();

      setState(() {
        _role = res?['role'] ?? 'helper';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _role = 'helper';
        _loading = false;
      });
    }
  }

  List<Widget> _getScreens() {
    if (_role == 'journeyman') {
      return [
        const SwipeScreen(mode: 'people'),
        JobPostScreen(),
        const MatchesScreen(),
        const ProfileScreen(),
      ];
    } else {
      return [
        const SwipeScreen(mode: 'people'),
        const SwipeScreen(mode: 'jobs'),
        const MatchesScreen(),
        const ProfileScreen(),
      ];
    }
  }

  List<BottomNavigationBarItem> _getNavItems() {
    if (_role == 'journeyman') {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.swipe),
          label: 'Discover',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.work),
          label: 'Post Job',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'Matches',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ];
    } else {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.swipe),
          label: 'People',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.work),
          label: 'Jobs',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'Matches',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
        ),
      );
    }

    final screens = _getScreens();
    final navItems = _getNavItems();

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF1e2d45), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFF111827),
          selectedItemColor: const Color(0xFFFF6B35),
          unselectedItemColor: const Color(0xFF8896b0),
          elevation: 0,
          items: navItems,
        ),
      ),
    );
  }
}