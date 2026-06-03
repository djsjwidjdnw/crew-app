import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../crew_constants.dart';
import '../error_helper.dart';
import 'chat_screen.dart';
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
  String? _error;

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
    setState(() {
      _loading = true;
      _error = null;
    });

    _userId = Supabase.instance.client.auth.currentUser?.id;
    if (_userId == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Not logged in';
      });
      return;
    }

    try {
      await Future.wait([_loadPeopleMatches(), _loadJobMatches()]);
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Error loading matches';
      });
      AppFeedback.showError(context, e);
    }
  }

  Future<void> _loadPeopleMatches() async {
    final res = await Supabase.instance.client
        .from('matches')
        .select('id, journeyman_id, helper_id, matched_at')
        .or('journeyman_id.eq.$_userId,helper_id.eq.$_userId')
        .order('matched_at', ascending: false);

    final matches = (res as List).cast<Map<String, dynamic>>();
    if (matches.isEmpty) {
      _peopleMatches = [];
      return;
    }

    // Collect the "other" user id for each match (de-duplicated).
    final otherIds = <String>{};
    for (final match in matches) {
      final otherId = match['journeyman_id'] == _userId
          ? match['helper_id']
          : match['journeyman_id'];
      if (otherId != null) otherIds.add(otherId.toString());
    }

    if (otherIds.isEmpty) {
      _peopleMatches = [];
      return;
    }

    // Single query for all the "other" users instead of one-per-row.
    final usersRes = await Supabase.instance.client
        .from('users')
        .select(
            'id, email, role, profiles(full_name, location_text, experience_level, trade_type, availability_status)')
        .inFilter('id', otherIds.toList());

    final usersById = <String, Map<String, dynamic>>{};
    for (final u in (usersRes as List).cast<Map<String, dynamic>>()) {
      usersById[u['id'].toString()] = u;
    }

    final enriched = <Map<String, dynamic>>[];
    for (final match in matches) {
      final otherId = match['journeyman_id'] == _userId
          ? match['helper_id']
          : match['journeyman_id'];
      if (otherId == null) continue;
      final user = usersById[otherId.toString()];
      if (user == null) continue;
      enriched.add({
        'match_id': match['id'],
        'matched_at': match['matched_at'],
        'user': user,
      });
    }

    _peopleMatches = enriched;
  }

  Future<void> _loadJobMatches() async {
    final likedRes = await Supabase.instance.client
        .from('job_swipes')
        .select('job_id')
        .eq('user_id', _userId!)
        .eq('liked', true);

    final likedJobIds = (likedRes as List).map((s) => s['job_id']).toList();

    if (likedJobIds.isEmpty) {
      _jobMatches = [];
      return;
    }

    final jobsRes = await Supabase.instance.client
        .from('jobs')
        .select(
            'id, title, description, location_text, hourly_rate, experience_required, duration_days, journeyman_id')
        .inFilter('id', likedJobIds)
        .eq('is_active', true);

    _jobMatches = (jobsRes as List).cast<Map<String, dynamic>>();
  }

  void _openChat(String matchId, String otherUserName, String otherUserRole) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          matchId: matchId,
          otherUserName: otherUserName,
          otherUserRole: otherUserRole,
        ),
      ),
    ).then((_) => _loadAll());
  }

  void _openJob(Map<String, dynamic> job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JobDetailScreen(job: job),
      ),
    ).then((_) => _loadAll());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MATCHES'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF6B35),
          labelColor: const Color(0xFFFF6B35),
          unselectedLabelColor: const Color(0xFF8896b0),
          tabs: const [
            Tab(text: 'PEOPLE'),
            Tab(text: 'JOBS'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF8896b0)),
            onPressed: _loadAll,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Color(0xFFef4444))),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadAll, child: const Text('RETRY')),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPeopleTab(),
                    _buildJobsTab(),
                  ],
                ),
    );
  }

  Widget _buildPeopleTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      color: CrewConstants.primary,
      child: _peopleMatches.isEmpty
          ? _buildEmptyScrollable('🤝', 'No people matches yet', 'Start swiping to find your crew')
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _peopleMatches.length,
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
                final expLabel = experience.isEmpty
                    ? ''
                    : CrewConstants.expToLabel(experience);
                final availability =
                    profile?['availability_status'] as String?;
                final availShort =
                    CrewConstants.availabilityShortLabel(availability);

                return GestureDetector(
                  onTap: () => _openChat(matchId, name, role),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1e2d45)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A5F),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFFF6B35), width: 2),
                          ),
                          child: const Icon(Icons.person, color: Color(0xFFFF6B35), size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Color(0xFFF0F4FF),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  _chip(
                                    role.toUpperCase(),
                                    role == 'journeyman'
                                        ? const Color(0xFF1E3A5F)
                                        : const Color(0xFFFF6B35).withOpacity(0.2),
                                    role == 'journeyman'
                                        ? const Color(0xFF7eb3ff)
                                        : const Color(0xFFFF6B35),
                                  ),
                                  if (expLabel.isNotEmpty)
                                    _chip(expLabel, const Color(0xFF1a2235), const Color(0xFF8896b0)),
                                  if (availShort.isNotEmpty)
                                    _chip(
                                      availShort,
                                      CrewConstants.availabilityColor(availability)
                                          .withOpacity(0.15),
                                      CrewConstants.availabilityColor(availability),
                                    ),
                                ],
                              ),
                              if (location.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, color: Color(0xFF8896b0), size: 12),
                                    const SizedBox(width: 2),
                                    Flexible(
                                      child: Text(
                                        location,
                                        style: const TextStyle(color: Color(0xFF8896b0), fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 4),
                              const Text(
                                'Tap to chat →',
                                style: TextStyle(color: Color(0xFFFF6B35), fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Color(0xFF8896b0), size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildJobsTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      color: CrewConstants.primary,
      child: _jobMatches.isEmpty
          ? _buildEmptyScrollable('📋', 'No saved jobs yet', 'Swipe right on jobs you like')
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _jobMatches.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final job = _jobMatches[index];
                final title = job['title'] ?? 'Untitled Job';
                final location = job['location_text'] ?? '';
                final rate = job['hourly_rate'];
                final duration = job['duration_days'];
                final experience = job['experience_required'] ?? 'any';
                final expLabel = CrewConstants.expToLabel(experience);

                return GestureDetector(
                  onTap: () => _openJob(job),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1e2d45)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E3A5F),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFFF6B35), width: 1.5),
                                ),
                                child: const Icon(Icons.work, color: Color(0xFFFF6B35), size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 15, fontWeight: FontWeight.w700),
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Color(0xFF8896b0), size: 20),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (location.isNotEmpty) _chip('📍 $location', const Color(0xFF1a2235), const Color(0xFF8896b0)),
                              if (rate != null) _chip('\$$rate/hr', const Color(0xFF22c55e).withOpacity(0.15), const Color(0xFF22c55e)),
                              if (duration != null) _chip('$duration days', const Color(0xFF1a2235), const Color(0xFF8896b0)),
                              _chip(expLabel, const Color(0xFF1E3A5F), const Color(0xFF7eb3ff)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            job['description'] ?? '',
                            style: const TextStyle(color: Color(0xFF8896b0), fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyScrollable(String emoji, String title, String subtitle) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: _buildEmpty(emoji, title, subtitle),
        ),
      ],
    );
  }

  Widget _buildEmpty(String emoji, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Color(0xFF8896b0))),
        ],
      ),
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
