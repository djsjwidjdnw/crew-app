import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../crew_constants.dart';
import 'chat_screen.dart';

class ViewProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final String? matchId;
  const ViewProfileScreen({super.key, required this.user, this.matchId});
  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> {
  List<Map<String, dynamic>> _certifications = [];
  bool _loadingCerts = true;

  @override
  void initState() { super.initState(); _loadCerts(); }

  Future<void> _loadCerts() async {
    try {
      final userId = widget.user['id'];
      if (userId == null) { setState(() => _loadingCerts = false); return; }
      final res = await Supabase.instance.client.from('certifications').select().eq('user_id', userId).order('created_at');
      _certifications = (res as List).cast<Map<String, dynamic>>();
    } catch (e) { _certifications = []; }
    setState(() => _loadingCerts = false);
  }

  void _viewCertPhoto(String url) {
    showDialog(context: context, builder: (ctx) => Dialog(backgroundColor: const Color(0xFF111827),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), child: Image.network(url, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Padding(padding: EdgeInsets.all(40), child: Text('Failed to load', style: TextStyle(color: Color(0xFF8896b0)))))),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CLOSE', style: TextStyle(color: Color(0xFFFF6B35)))),
      ])));
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.user['profiles'] as Map<String, dynamic>?;
    final name = profile?['full_name'] ?? widget.user['email'] ?? 'Unknown';
    final bio = profile?['bio'] ?? '';
    final location = profile?['location_text'] ?? '';
    final experience = profile?['experience_level'] ?? '';
    final phone = profile?['phone'] ?? '';
    final role = widget.user['role'] ?? '';
    final tradeType = profile?['trade_type'] ?? 'Welder';
    final yearsInField = profile?['years_in_field'] ?? 0;
    final photoUrl = profile?['profile_photo_url'];

    return Scaffold(
      appBar: AppBar(title: const Text('PROFILE'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
        Container(width: double.infinity, decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1e2d45))),
          child: Column(children: [
            Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 28), decoration: const BoxDecoration(color: Color(0xFF1a2235), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
              child: Column(children: [
                _buildAvatar(photoUrl),
                const SizedBox(height: 12),
                Text(name, style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: role == 'journeyman' ? const Color(0xFF1E3A5F) : const Color(0xFFFF6B35).withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                  child: Text(role.toUpperCase(), style: TextStyle(color: role == 'journeyman' ? const Color(0xFF7eb3ff) : const Color(0xFFFF6B35), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2))),
              ])),
            Padding(padding: const EdgeInsets.all(16), child: Column(children: [
              if (location.isNotEmpty) _infoRow(Icons.location_on, location),
              if (experience.isNotEmpty) _infoRow(Icons.work, CrewConstants.expToLabel(experience)),
              _infoRow(Icons.build, tradeType),
              if (yearsInField > 0) _infoRow(Icons.calendar_today, '$yearsInField years in the field'),
              if (bio.isNotEmpty) ...[const SizedBox(height: 8), Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF0A0E1A), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF1e2d45))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('ABOUT', style: TextStyle(color: Color(0xFF8896b0), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2)), const SizedBox(height: 6), Text(bio, style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 14, height: 1.5))]))],
            ])),
          ])),

        const SizedBox(height: 16),

        if (widget.matchId != null)
          ElevatedButton.icon(onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(matchId: widget.matchId!, otherUserName: name, otherUserRole: role)));
          }, icon: const Icon(Icons.chat, size: 18), label: const Text('MESSAGE')),

        const SizedBox(height: 16),

        // Real certifications
        _sectionCard('CERTIFICATIONS', Icons.verified,
          _loadingCerts ? [const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))]
          : _certifications.isEmpty ? [const Text('No certifications added yet.', style: TextStyle(color: Color(0xFF8896b0), fontSize: 13))]
          : _certifications.map((c) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
              Icon(c['status'] == 'verified' ? Icons.check_circle : Icons.pending, color: c['status'] == 'verified' ? const Color(0xFF22c55e) : const Color(0xFFfbbf24), size: 18),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c['name'] ?? '', style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 14)),
                if (c['expiry_date'] != null) Text('Expires: ${c['expiry_date']}', style: const TextStyle(color: Color(0xFF8896b0), fontSize: 10)),
              ])),
              if (c['photo_url'] != null) IconButton(icon: const Icon(Icons.visibility, color: Color(0xFF7eb3ff), size: 18), onPressed: () => _viewCertPhoto(c['photo_url']), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 30, minHeight: 30)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: c['status'] == 'verified' ? const Color(0xFF22c55e).withOpacity(0.15) : const Color(0xFFfbbf24).withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                child: Text(c['status'] == 'verified' ? 'Verified' : 'Pending', style: TextStyle(color: c['status'] == 'verified' ? const Color(0xFF22c55e) : const Color(0xFFfbbf24), fontSize: 10, fontWeight: FontWeight.w700))),
            ]))).toList(),
        ),

        const SizedBox(height: 32),
      ])),
    );
  }

  Widget _buildAvatar(String? photoUrl) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return Container(width: 90, height: 90, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFF6B35), width: 3), image: DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover)));
    }
    return Container(width: 90, height: 90, decoration: BoxDecoration(color: const Color(0xFF1E3A5F), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFF6B35), width: 3)), child: const Icon(Icons.person, color: Color(0xFFFF6B35), size: 48));
  }

  Widget _infoRow(IconData icon, String text) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Icon(icon, color: const Color(0xFFFF6B35), size: 18), const SizedBox(width: 10), Expanded(child: Text(text, style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 14)))]));

  Widget _sectionCard(String title, IconData icon, List<Widget> children) {
    return Container(width: double.infinity, decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1e2d45))), padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: const Color(0xFFFF6B35), size: 18), const SizedBox(width: 8), Text(title, style: const TextStyle(color: Color(0xFF8896b0), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2))]), const SizedBox(height: 10), ...children]));
  }
}