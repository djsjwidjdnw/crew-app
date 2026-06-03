import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../crew_constants.dart';
import '../error_helper.dart';
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
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', userId)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _role = res?['role'] ?? CrewConstants.roleHelper;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Keep a safe default so the app still works, but surface the error.
      setState(() {
        _role = CrewConstants.roleHelper;
        _loading = false;
      });
      AppFeedback.showError(context, e);
    }
  }

  List<Widget> _getScreens() {
    if (_role == CrewConstants.roleJourneyman) {
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
    if (_role == CrewConstants.roleJourneyman) {
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
          child: CircularProgressIndicator(color: CrewConstants.primary),
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
            top: BorderSide(color: CrewConstants.border, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: CrewConstants.surface,
          selectedItemColor: CrewConstants.primary,
          unselectedItemColor: CrewConstants.textSecondary,
          elevation: 0,
          items: navItems,
        ),
      ),
    );
  }
}
