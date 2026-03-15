import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_screen.dart';
import 'view_profile_screen.dart';
import 'job_detail_screen.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _peopleMatches = [];
  List<Map<String, dynamic>> _jobMatches = [];
  bool _loading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    _userId = Supabase.instance.client.auth.currentUser?.id;
    if (_userId == null) { setState(() => _loading = false); return; }
    try {
      await _loadPeopleMatches();
      await _loadJobMatches();
    } catch (e) {
      debugPrint('Error loading matches: $e');
    }
    setState(() => _loading = false);
  }

  Future<void> _loadPeopleMatches() async {
    try {
      final res = await Supabase.instance.client
          .from('matches')
          .select()
          .or('journeyman_id.eq.$_userId,helper_id.eq.$_userId')
          .order('matched_at', ascending: false);
      final matches = (res as List).cast<Map<String, dynamic>>();
      List<Map<String, dynamic>> enriched = [];
      for (final match in matches) {
        final otherId = match['journeyman_id'] == _userId ? match['helper_id'] : match['journeyman_id'];
        try {
          final userRes = await Supabase.instance.client.from('users').select('id, email, role').eq('id', otherId).maybeSingle();
          if (userRes == null) continue;
          final profileRes = await Supabase.instance.client.from('profiles').select('full_name, location_text, experience_level, bio, phone, trade_type, years_in_field').eq('user_id', otherId).maybeSingle();
          final combined = Map<String, dynamic>.from(userRes);
          combined['profiles'] = profileRes;
          enriched.add({'match_id': match['id'], 'matched_at': match['matched_at'], 'user': combined});
        } catch (e) { debugPrint('Error enriching: $e'); }
      }
      _peopleMatches = enriched;
    } catch (e) { _peopleMatches = []; }
  }

  Future<void> _loadJobMatches() async {
    try {
      final likedRes = await Supabase.instance.client.from('job_swipes').select('job_id').eq('user_id', _userId!).eq('liked', true);
      final likedJobIds = (likedRes as List).map((s) => s['job_id']).toList();
      if (likedJobIds.isEmpty) { _jobMatches = []; return; }
      final jobsRes = await Supabase.instance.client.from('jobs').select('id, title, description, location_text, hourly_rate, experience_required, duration_days, journeyman_id').inFilter('id', likedJobIds).eq('is_active', true);
      _jobMatches = (jobsRes as List).cast<Map<String, dynamic>>();
    } catch (e) { _jobMatches = []; }
  }

  void _openProfile(Map<String, dynamic> user, String matchId) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ViewProfileScreen(user: user, matchId: matchId)));
  }

  void _openChat(String matchId, String name, String role) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(matchId: matchId, otherUserName: name, otherUserRole: role))).then((_) => _loadAll());
  }

  void _openJobDetail(Map<String, dynamic> job) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => JobDetailScreen(job: job)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MATCHES'),
        bottom: TabBar(controller: _tabController, indicatorColor: const Color(0xFFFF6B35), labelColor: const Color(0xFFFF6B35), unselectedLabelColor: const Color(0xFF8896b0), tabs: const [Tab(text: 'PEOPLE'), Tab(text: 'JOBS')]),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF8896b0)), onPressed: _loadAll)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
          : TabBarView(controller: _tabController, children: [_buildPeopleTab(), _buildJobsTab()]),
    );
  }

  Widget _buildPeopleTab() {
    if (_peopleMatches.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🤝', style: TextStyle(fontSize: 48)), const SizedBox(height: 16),
        const Text('No people matches yet', style: TextStyle(color: Color(0xFFF0F4FF), fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8), const Text('Start swiping to find your crew', style: TextStyle(color: Color(0xFF8896b0))),
      ]));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16), itemCount: _peopleMatches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final match = _peopleMatches[index];
        final matchId = match['match_id'].toString();
        final user = match['user'] as Map<String, dynamic>;
        final profile = user['profiles'] as Map<String, dynamic>?;
        final name = profile?['full_name'] ?? user['email'] ?? 'Unknown';
        final location = profile?['location_text'] ?? '';
        final role = user['role'] ?? '';
        final experience = profile?['experience_level'] ?? '';
        String expLabel = experience;
        switch (experience) {
          case 'apprentice_1st': expLabel = '1st Year'; break;
          case 'apprentice_2nd': expLabel = '2nd Year'; break;
          case 'apprentice_3rd': expLabel = '3rd Year'; break;
          case 'apprentice_4th': expLabel = '4th Year'; break;
          case 'journeyman': expLabel = 'Journeyman'; break;
          case 'master': expLabel = 'Master'; break;
        }
        return Container(
          decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1e2d45))),
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            GestureDetector(
              onTap: () => _openProfile(user, matchId),
              child: Container(width: 52, height: 52, decoration: BoxDecoration(color: const Color(0xFF1E3A5F), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFF6B35), width: 2)), child: const Icon(Icons.person, color: Color(0xFFFF6B35), size: 28)),
            ),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: () => _openProfile(user, matchId),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(color: Color(0xFFF0F4FF), fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Wrap(spacing: 4, runSpacing: 4, children: [
                  _chip(role.toUpperCase(), role == 'journeyman' ? const Color(0xFF1E3A5F) : const Color(0xFFFF6B35).withOpacity(0.2), role == 'journeyman' ? const Color(0xFF7eb3ff) : const Color(0xFFFF6B35)),
                  if (expLabel.isNotEmpty) _chip(expLabel, const Color(0xFF1a2235), const Color(0xFF8896b0)),
                ]),
                if (location.isNotEmpty) ...[const SizedBox(height: 3), Row(children: [
                  const Icon(Icons.location_on, color: Color(0xFF8896b0), size: 12), const SizedBox(width: 2),
                  Flexible(child: Text(location, style: const TextStyle(color: Color(0xFF8896b0), fontSize: 11), overflow: TextOverflow.ellipsis)),
                ])],
              ]),
            )),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _openChat(matchId, name, role),
              child: Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFFF6B35), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.chat, color: Colors.white, size: 20)),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildJobsTab() {
    if (_jobMatches.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('📋', style: TextStyle(fontSize: 48)), const SizedBox(height: 16),
        const Text('No saved jobs yet', style: TextStyle(color: Color(0xFFF0F4FF), fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8), const Text('Swipe right on jobs you like', style: TextStyle(color: Color(0xFF8896b0))),
      ]));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16), itemCount: _jobMatches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final job = _jobMatches[index];
        final title = job['title'] ?? 'Untitled Job';
        final location = job['location_text'] ?? '';
        final rate = job['hourly_rate'];
        final duration = job['duration_days'];
        final experience = job['experience_required'] ?? 'any';
        String expLabel = experience;
        switch (experience) { case 'any': expLabel = 'Any Level'; break; case 'apprentice': expLabel = 'Apprentice'; break; case 'journeyman': expLabel = 'Journeyman'; break; case 'master': expLabel = 'Master'; break; }
        return GestureDetector(
          onTap: () => _openJobDetail(job),
          child: Container(
            decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1e2d45))),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFF1E3A5F), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFF6B35), width: 1.5)), child: const Icon(Icons.work, color: Color(0xFFFF6B35), size: 22)),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 15, fontWeight: FontWeight.w700))),
                const Icon(Icons.chevron_right, color: Color(0xFF8896b0), size: 20),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (location.isNotEmpty) _chip('📍 $location', const Color(0xFF1a2235), const Color(0xFF8896b0)),
                if (rate != null) _chip('\$$rate/hr', const Color(0xFF22c55e).withOpacity(0.15), const Color(0xFF22c55e)),
                if (duration != null) _chip('$duration days', const Color(0xFF1a2235), const Color(0xFF8896b0)),
                _chip(expLabel, const Color(0xFF1E3A5F), const Color(0xFF7eb3ff)),
              ]),
              const SizedBox(height: 8),
              Text(job['description'] ?? '', style: const TextStyle(color: Color(0xFF8896b0), fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              const Text('Tap for full details →', style: TextStyle(color: Color(0xFFFF6B35), fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ),
        );
      },
    );
  }

  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}
