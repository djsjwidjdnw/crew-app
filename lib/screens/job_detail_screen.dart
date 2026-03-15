import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_screen.dart';

class JobDetailScreen extends StatefulWidget {
  final Map<String, dynamic> job;
  const JobDetailScreen({super.key, required this.job});
  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  String? _matchId;
  String _posterName = 'Unknown';
  String _posterRole = 'journeyman';
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadMatchAndPoster(); }

  Future<void> _loadMatchAndPoster() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final journeymanId = widget.job['journeyman_id'];
    if (userId == null || journeymanId == null) { setState(() => _loading = false); return; }
    try {
      final posterRes = await Supabase.instance.client.from('profiles').select('full_name').eq('user_id', journeymanId).maybeSingle();
      _posterName = posterRes?['full_name'] ?? 'Unknown';
      final matchRes = await Supabase.instance.client.from('matches').select('id').eq('journeyman_id', journeymanId).eq('helper_id', userId).maybeSingle();
      if (matchRes != null) { _matchId = matchRes['id'].toString(); }
    } catch (e) { debugPrint('Error: $e'); }
    setState(() => _loading = false);
  }

  Future<void> _createMatchAndChat() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final journeymanId = widget.job['journeyman_id'];
    if (userId == null || journeymanId == null) return;
    try {
      final res = await Supabase.instance.client.from('matches').insert({'journeyman_id': journeymanId, 'helper_id': userId, 'job_id': widget.job['id']}).select('id').single();
      _matchId = res['id'].toString();
      if (mounted) _openChat();
    } catch (e) {
      final existing = await Supabase.instance.client.from('matches').select('id').eq('journeyman_id', journeymanId).eq('helper_id', userId).maybeSingle();
      if (existing != null) { _matchId = existing['id'].toString(); if (mounted) _openChat(); }
      else { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFef4444))); }
    }
  }

  void _openChat() {
    if (_matchId == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(matchId: _matchId!, otherUserName: _posterName, otherUserRole: _posterRole)));
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.job['title'] ?? 'Untitled Job';
    final description = widget.job['description'] ?? 'No description.';
    final location = widget.job['location_text'] ?? 'Alberta';
    final rate = widget.job['hourly_rate'];
    final duration = widget.job['duration_days'];
    final experience = widget.job['experience_required'] ?? 'any';
    String expLabel = experience;
    switch (experience) { case 'any': expLabel = 'Any Level'; break; case 'apprentice': expLabel = 'Apprentice'; break; case 'journeyman': expLabel = 'Journeyman'; break; case 'master': expLabel = 'Master'; break; }

    return Scaffold(
      appBar: AppBar(title: const Text('JOB DETAILS'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      body: _loading ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
          : SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: double.infinity, decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1e2d45))),
                child: Column(children: [
                  Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 28), decoration: const BoxDecoration(color: Color(0xFF1a2235), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                    child: Column(children: [
                      Container(width: 80, height: 80, decoration: BoxDecoration(color: const Color(0xFF1E3A5F), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFFF6B35), width: 2)), child: const Icon(Icons.work, color: Color(0xFFFF6B35), size: 42)),
                      const SizedBox(height: 14),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(title, style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 22, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
                      const SizedBox(height: 6),
                      Text('Posted by $_posterName', style: const TextStyle(color: Color(0xFF8896b0), fontSize: 13)),
                    ])),
                  Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                    _detailRow(Icons.location_on, 'Location', location),
                    if (rate != null) _detailRow(Icons.attach_money, 'Pay Rate', '\$$rate/hour'),
                    if (duration != null) _detailRow(Icons.schedule, 'Duration', '$duration days'),
                    _detailRow(Icons.star, 'Experience', expLabel),
                  ])),
                ])),
              const SizedBox(height: 16),
              _sec('JOB DESCRIPTION', Icons.description, [Text(description, style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 14, height: 1.6))]),
              const SizedBox(height: 12),
              _sec('WHAT TO EXPECT', Icons.info_outline, [
                _ei('📍', 'Work location: $location'),
                if (rate != null) _ei('💰', 'Pay: \$$rate/hr ${rate >= 45 ? "(above average)" : ""}'),
                if (duration != null) _ei('📅', 'Duration: $duration days'),
                _ei('🔧', 'Trade: Welding / Fabrication / Pipeline'),
                _ei('👷', 'Experience: $expLabel'),
                _ei('🏕️', 'Camp/LOA details available in chat'),
              ]),
              const SizedBox(height: 12),
              _sec(_matchId != null ? 'CONTACT ${_posterName.toUpperCase()}' : 'GET CONNECTED', Icons.message, [
                if (_matchId != null) ...[
                  Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF22c55e).withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF22c55e).withOpacity(0.3))),
                    child: Row(children: [const Icon(Icons.check_circle, color: Color(0xFF22c55e), size: 20), const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('You\'re connected!', style: TextStyle(color: Color(0xFF22c55e), fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('Message $_posterName directly about this job.', style: const TextStyle(color: Color(0xFF8896b0), fontSize: 12)),
                      ]))])),
                  const SizedBox(height: 12),
                  const Text('DISCUSS IN CHAT:', style: TextStyle(color: Color(0xFF8896b0), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2)),
                  const SizedBox(height: 8),
                  _si(Icons.badge, 'Share your certifications (CSTS, H2S, Fall Pro)'),
                  _si(Icons.calendar_today, 'Confirm availability and start date'),
                  _si(Icons.directions_car, 'Discuss travel (drive-in or fly-in)'),
                  _si(Icons.build, 'Confirm your tools and PPE'),
                  _si(Icons.person, 'Offer references from past journeymen'),
                ] else ...[
                  Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF0A0E1A), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.3))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Row(children: [Icon(Icons.info, color: Color(0xFFFF6B35), size: 16), SizedBox(width: 8), Text('Ready to connect?', style: TextStyle(color: Color(0xFFFF6B35), fontSize: 13, fontWeight: FontWeight.w700))]),
                      const SizedBox(height: 8),
                      Text('Tap below to start a conversation with $_posterName about this job. Share your certs, discuss pay, and sort out the details.', style: const TextStyle(color: Color(0xFF8896b0), fontSize: 12, height: 1.4)),
                    ])),
                ],
              ]),
              const SizedBox(height: 12),
              _sec('TYPICAL REQUIREMENTS', Icons.assignment, [
                _ri('CSTS-2020 (Construction Safety Training)'), _ri('H2S Alive Certificate'), _ri('Fall Protection Training'),
                _ri('Valid government-issued ID'), _ri('Steel-toed boots and basic PPE'),
                if (expLabel == 'Journeyman' || expLabel == 'Master') _ri('Journeyman or Master ticket'),
              ]),
              const SizedBox(height: 32),
            ])),
      bottomNavigationBar: _loading ? null : Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: const BoxDecoration(color: Color(0xFF111827), border: Border(top: BorderSide(color: Color(0xFF1e2d45)))),
        child: _matchId != null
            ? ElevatedButton.icon(onPressed: _openChat, icon: const Icon(Icons.chat, size: 18), label: Text('MESSAGE ${_posterName.toUpperCase()}'))
            : ElevatedButton.icon(onPressed: _createMatchAndChat, icon: const Icon(Icons.handshake, size: 18), label: Text('CONNECT WITH ${_posterName.toUpperCase()}')),
      ),
    );
  }

  Widget _detailRow(IconData i, String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Icon(i, color: const Color(0xFFFF6B35), size: 18), const SizedBox(width: 10), Text('$l: ', style: const TextStyle(color: Color(0xFF8896b0), fontSize: 13)), Expanded(child: Text(v, style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 14, fontWeight: FontWeight.w600)))]));
  Widget _ei(String e, String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(e, style: const TextStyle(fontSize: 16)), const SizedBox(width: 10), Expanded(child: Text(t, style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 13, height: 1.4)))]));
  Widget _si(IconData i, String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [Icon(i, color: const Color(0xFFFF6B35), size: 15), const SizedBox(width: 8), Expanded(child: Text(t, style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 12)))]));
  Widget _ri(String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [const Icon(Icons.check_circle_outline, color: Color(0xFF8896b0), size: 16), const SizedBox(width: 8), Expanded(child: Text(t, style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 13)))]));
  Widget _sec(String t, IconData i, List<Widget> c) => Container(width: double.infinity, decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1e2d45))), padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(i, color: const Color(0xFFFF6B35), size: 18), const SizedBox(width: 8), Text(t, style: const TextStyle(color: Color(0xFF8896b0), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2))]), const SizedBox(height: 12), ...c]));
}
