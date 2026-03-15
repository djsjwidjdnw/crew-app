import 'package:flutter/material.dart';
import 'chat_screen.dart';

class ViewProfileScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  final String? matchId;

  const ViewProfileScreen({
    super.key,
    required this.user,
    this.matchId,
  });

  String _getExperienceLabel(String value) {
    switch (value) {
      case 'apprentice_1st': return '1st Year Apprentice';
      case 'apprentice_2nd': return '2nd Year Apprentice';
      case 'apprentice_3rd': return '3rd Year Apprentice';
      case 'apprentice_4th': return '4th Year Apprentice';
      case 'journeyman': return 'Journeyman';
      case 'master': return 'Master';
      default: return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = user['profiles'] as Map<String, dynamic>?;
    final name = profile?['full_name'] ?? user['email'] ?? 'Unknown';
    final bio = profile?['bio'] ?? '';
    final location = profile?['location_text'] ?? '';
    final experience = profile?['experience_level'] ?? '';
    final phone = profile?['phone'] ?? '';
    final role = user['role'] ?? '';
    final email = user['email'] ?? '';
    final tradeType = profile?['trade_type'] ?? 'Welding';
    final yearsInField = profile?['years_in_field'] ?? 0;

    // Mock certifications based on role
    final List<Map<String, String>> certs = role == 'journeyman'
        ? [
            {'name': 'Journeyman Welder Certificate', 'status': 'Verified'},
            {'name': 'CSTS-2020', 'status': 'Verified'},
            {'name': 'H2S Alive', 'status': 'Verified'},
            {'name': 'Fall Protection', 'status': 'Verified'},
            {'name': 'Confined Space Entry', 'status': 'Verified'},
            {'name': 'CWB Certified (W47.1)', 'status': 'Verified'},
          ]
        : [
            {'name': 'CSTS-2020', 'status': 'Verified'},
            {'name': 'H2S Alive', 'status': 'Verified'},
            {'name': 'Fall Protection', 'status': 'Verified'},
            {'name': 'First Aid / CPR', 'status': 'Verified'},
            {'name': 'Ground Disturbance Level II', 'status': 'Pending'},
          ];

    // Mock endorsements
    final List<Map<String, String>> endorsements = role == 'journeyman'
        ? [
            {'from': 'Mike H.', 'text': 'Best foreman I\'ve worked under. Fair pay, safe site, keeps everyone busy.', 'role': 'Helper'},
            {'from': 'Kyle R.', 'text': 'Ran a tight crew on the Suncor turnaround. Would work for him again no question.', 'role': 'Helper'},
            {'from': 'Jason T.', 'text': 'Good communicator. Always had the materials ready and a plan for the day.', 'role': 'Apprentice'},
          ]
        : [
            {'from': 'Dave M.', 'text': 'Hard worker, shows up on time every day. Picks things up fast.', 'role': 'Journeyman'},
            {'from': 'Rick S.', 'text': 'One of the better helpers I\'ve had. Keeps the area clean and anticipates what you need.', 'role': 'Journeyman'},
          ];

    // Mock completed jobs
    final List<Map<String, String>> completedJobs = role == 'journeyman'
        ? [
            {'title': 'Pipeline Tie-In - Drayton Valley', 'duration': '28 days', 'year': '2025'},
            {'title': 'Suncor Turnaround - Fort McMurray', 'duration': '42 days', 'year': '2025'},
            {'title': 'Structural Steel - Red Deer', 'duration': '14 days', 'year': '2024'},
            {'title': 'Gas Plant Maintenance - Edson', 'duration': '21 days', 'year': '2024'},
          ]
        : [
            {'title': 'Helper - Pipeline Crew (Rocky Mountain House)', 'duration': '21 days', 'year': '2025'},
            {'title': 'Helper - Suncor Turnaround', 'duration': '35 days', 'year': '2025'},
            {'title': 'Apprentice - Fabrication Shop (Red Deer)', 'duration': '90 days', 'year': '2024'},
          ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('PROFILE'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header card
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1e2d45)),
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1a2235),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A5F),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFFF6B35), width: 3),
                          ),
                          child: const Icon(Icons.person, color: Color(0xFFFF6B35), size: 48),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          name,
                          style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: role == 'journeyman' ? const Color(0xFF1E3A5F) : const Color(0xFFFF6B35).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            role.toUpperCase(),
                            style: TextStyle(
                              color: role == 'journeyman' ? const Color(0xFF7eb3ff) : const Color(0xFFFF6B35),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (location.isNotEmpty) _infoRow(Icons.location_on, location),
                        if (experience.isNotEmpty) _infoRow(Icons.work, _getExperienceLabel(experience)),
                        _infoRow(Icons.build, tradeType),
                        if (yearsInField > 0) _infoRow(Icons.calendar_today, '$yearsInField years in the field'),
                        if (bio.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A0E1A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF1e2d45)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('ABOUT', style: TextStyle(color: Color(0xFF8896b0), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2)),
                                const SizedBox(height: 6),
                                Text(bio, style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 14, height: 1.5)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Message button (only if matched)
            if (matchId != null)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        matchId: matchId!,
                        otherUserName: name,
                        otherUserRole: role,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat, size: 18),
                label: const Text('MESSAGE'),
              ),

            const SizedBox(height: 16),

            // Certifications
            _sectionCard(
              'CERTIFICATIONS',
              Icons.verified,
              certs.map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      c['status'] == 'Verified' ? Icons.check_circle : Icons.pending,
                      color: c['status'] == 'Verified' ? const Color(0xFF22c55e) : const Color(0xFFfbbf24),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(c['name']!, style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 14)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: c['status'] == 'Verified'
                            ? const Color(0xFF22c55e).withOpacity(0.15)
                            : const Color(0xFFfbbf24).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        c['status']!,
                        style: TextStyle(
                          color: c['status'] == 'Verified' ? const Color(0xFF22c55e) : const Color(0xFFfbbf24),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),

            const SizedBox(height: 12),

            // Completed Jobs
            _sectionCard(
              'COMPLETED JOBS',
              Icons.construction,
              completedJobs.map((j) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.work, color: Color(0xFFFF6B35), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(j['title']!, style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 13, fontWeight: FontWeight.w600)),
                          Text('${j['duration']} • ${j['year']}', style: const TextStyle(color: Color(0xFF8896b0), fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),

            const SizedBox(height: 12),

            // Endorsements
            _sectionCard(
              'CREW ENDORSEMENTS',
              Icons.thumb_up,
              endorsements.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0E1A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF1e2d45)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(e['from']!, style: const TextStyle(color: Color(0xFFFF6B35), fontSize: 13, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1a2235),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(e['role']!, style: const TextStyle(color: Color(0xFF8896b0), fontSize: 9, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('"${e['text']!}"', style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 13, height: 1.4, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              )).toList(),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFF6B35), size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 14))),
        ],
      ),
    );
  }

  Widget _sectionCard(String title, IconData icon, List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1e2d45)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFFF6B35), size: 18),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Color(0xFF8896b0), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2)),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
