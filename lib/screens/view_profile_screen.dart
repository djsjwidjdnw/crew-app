// Read-only profile view for another user (opened from swipe / matches / chat).
// Shows their profile, availability, average rating, endorsements left by other
// crew members, and certifications.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../crew_constants.dart';
import '../error_helper.dart';
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
  List<Map<String, dynamic>> _endorsements = [];
  bool _loading = true;

  double? _avgRating;
  int _ratingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final userId = widget.user['id'];
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final client = Supabase.instance.client;
    try {
      // Certifications
      final certRes = await client
          .from('certifications')
          .select()
          .eq('user_id', userId)
          .order('created_at');
      final certs = (certRes as List).cast<Map<String, dynamic>>();

      // Endorsements + the names of who left them (single extra query).
      final endRes = await client
          .from('endorsements')
          .select('content, created_at, from_user_id')
          .eq('to_user_id', userId)
          .order('created_at', ascending: false);
      final endorsements = (endRes as List).cast<Map<String, dynamic>>();
      final fromIds = endorsements
          .map((e) => e['from_user_id'])
          .where((id) => id != null)
          .toSet()
          .toList();
      final Map<String, String> nameById = {};
      if (fromIds.isNotEmpty) {
        final profRes = await client
            .from('profiles')
            .select('user_id, full_name')
            .inFilter('user_id', fromIds);
        for (final p in (profRes as List).cast<Map<String, dynamic>>()) {
          nameById[p['user_id'].toString()] =
              (p['full_name'] ?? 'A crew member').toString();
        }
      }
      for (final e in endorsements) {
        e['from_name'] = nameById[e['from_user_id'].toString()] ?? 'A crew member';
      }

      // Ratings average
      final ratingRes =
          await client.from('ratings').select('score').eq('to_user_id', userId);
      final ratings = (ratingRes as List).cast<Map<String, dynamic>>();
      double? avg;
      if (ratings.isNotEmpty) {
        final sum = ratings.fold<int>(
            0, (acc, r) => acc + ((r['score'] as num?)?.toInt() ?? 0));
        avg = sum / ratings.length;
      }

      if (!mounted) return;
      setState(() {
        _certifications = certs;
        _endorsements = endorsements;
        _avgRating = avg;
        _ratingCount = ratings.length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppFeedback.showError(context, e, fallback: 'Could not load profile');
    }
  }

  void _viewCertPhoto(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: CrewConstants.surface,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.network(url,
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('Failed to load',
                        style: TextStyle(color: CrewConstants.textSecondary)))),
          ),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CLOSE',
                  style: TextStyle(color: CrewConstants.primary))),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.user['profiles'] as Map<String, dynamic>?;
    final name = profile?['full_name'] ?? widget.user['email'] ?? 'Unknown';
    final bio = profile?['bio'] ?? '';
    final location = profile?['location_text'] ?? '';
    final experience = profile?['experience_level'] ?? '';
    final role = widget.user['role'] ?? '';
    final tradeType = profile?['trade_type'] ?? 'Welder';
    final yearsInField = profile?['years_in_field'] ?? 0;
    final photoUrl = profile?['profile_photo_url'];
    final availability = profile?['availability_status'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PROFILE'),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
      ),
      body: RefreshIndicator(
        color: CrewConstants.primary,
        onRefresh: _loadAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                  color: CrewConstants.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: CrewConstants.border)),
              child: Column(children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: const BoxDecoration(
                      color: CrewConstants.panel,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16))),
                  child: Column(children: [
                    _buildAvatar(photoUrl),
                    const SizedBox(height: 12),
                    Text(name,
                        style: const TextStyle(
                            color: CrewConstants.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                              color: role == 'journeyman'
                                  ? CrewConstants.secondary
                                  : CrewConstants.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4)),
                          child: Text(role.toString().toUpperCase(),
                              style: TextStyle(
                                  color: role == 'journeyman'
                                      ? CrewConstants.accentBlue
                                      : CrewConstants.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2)),
                        ),
                        if (availability != null) _availabilityChip(availability),
                      ],
                    ),
                    if (_avgRating != null) ...[
                      const SizedBox(height: 8),
                      _ratingRow(_avgRating!, _ratingCount),
                    ],
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    if (location.isNotEmpty)
                      _infoRow(Icons.location_on, location),
                    if (experience.isNotEmpty)
                      _infoRow(Icons.work, CrewConstants.expToLabel(experience)),
                    _infoRow(Icons.build, tradeType),
                    if (yearsInField > 0)
                      _infoRow(Icons.calendar_today,
                          '$yearsInField years in the field'),
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: CrewConstants.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: CrewConstants.border)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('ABOUT',
                                  style: TextStyle(
                                      color: CrewConstants.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2)),
                              const SizedBox(height: 6),
                              Text(bio,
                                  style: const TextStyle(
                                      color: CrewConstants.textPrimary,
                                      fontSize: 14,
                                      height: 1.5)),
                            ]),
                      )
                    ],
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            if (widget.matchId != null)
              ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ChatScreen(
                                matchId: widget.matchId!,
                                otherUserName: name,
                                otherUserRole: role)));
                  },
                  icon: const Icon(Icons.chat, size: 18),
                  label: const Text('MESSAGE')),
            const SizedBox(height: 16),
            _buildEndorsements(),
            const SizedBox(height: 12),
            _buildCertifications(),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }

  Widget _buildEndorsements() {
    return _sectionCard(
      'ENDORSEMENTS',
      Icons.thumb_up,
      _loading
          ? [
              const Center(
                  child: CircularProgressIndicator(color: CrewConstants.primary))
            ]
          : _endorsements.isEmpty
              ? [
                  const Text('No endorsements yet.',
                      style: TextStyle(
                          color: CrewConstants.textSecondary, fontSize: 13))
                ]
              : _endorsements
                  .map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: CrewConstants.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: CrewConstants.border)),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Icon(Icons.format_quote,
                                      color: CrewConstants.success, size: 14),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                        (e['from_name'] ?? 'A crew member')
                                            .toString(),
                                        style: const TextStyle(
                                            color: CrewConstants.textPrimary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ]),
                                const SizedBox(height: 4),
                                Text((e['content'] ?? '').toString(),
                                    style: const TextStyle(
                                        color: CrewConstants.textPrimary,
                                        fontSize: 13,
                                        height: 1.4)),
                              ]),
                        ),
                      ))
                  .toList(),
    );
  }

  Widget _buildCertifications() {
    return _sectionCard(
      'CERTIFICATIONS',
      Icons.verified,
      _loading
          ? [
              const Center(
                  child: CircularProgressIndicator(color: CrewConstants.primary))
            ]
          : _certifications.isEmpty
              ? [
                  const Text('No certifications added yet.',
                      style: TextStyle(
                          color: CrewConstants.textSecondary, fontSize: 13))
                ]
              : _certifications.map((c) {
                  final expiry = c['expiry_date']?.toString();
                  final expiryLabel = CrewConstants.certExpiryLabel(expiry);
                  final expiryColor = CrewConstants.certExpiryColor(expiry);
                  final verified = c['status'] == 'verified';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Icon(verified ? Icons.check_circle : Icons.pending,
                          color: verified
                              ? CrewConstants.success
                              : CrewConstants.warning,
                          size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(c['name'] ?? '',
                                style: const TextStyle(
                                    color: CrewConstants.textPrimary,
                                    fontSize: 14)),
                            if (expiry != null && expiry.isNotEmpty)
                              Text(
                                  expiryLabel.isNotEmpty
                                      ? '$expiryLabel · $expiry'
                                      : 'Expires: $expiry',
                                  style: TextStyle(
                                      color: expiryLabel.isNotEmpty
                                          ? expiryColor
                                          : CrewConstants.textSecondary,
                                      fontSize: 10,
                                      fontWeight: expiryLabel.isNotEmpty
                                          ? FontWeight.w700
                                          : FontWeight.normal)),
                          ])),
                      if (c['photo_url'] != null)
                        IconButton(
                            icon: const Icon(Icons.visibility,
                                color: CrewConstants.accentBlue, size: 18),
                            onPressed: () => _viewCertPhoto(c['photo_url']),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 30, minHeight: 30)),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: (verified
                                      ? CrewConstants.success
                                      : CrewConstants.warning)
                                  .withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4)),
                          child: Text(verified ? 'Verified' : 'Pending',
                              style: TextStyle(
                                  color: verified
                                      ? CrewConstants.success
                                      : CrewConstants.warning,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700))),
                    ]),
                  );
                }).toList(),
    );
  }

  Widget _availabilityChip(String status) {
    final color = CrewConstants.availabilityColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(CrewConstants.availabilityLabel(status).toUpperCase(),
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
      ]),
    );
  }

  Widget _ratingRow(double avg, int count) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.star, color: CrewConstants.warning, size: 18),
      const SizedBox(width: 4),
      Text(avg.toStringAsFixed(1),
          style: const TextStyle(
              color: CrewConstants.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700)),
      const SizedBox(width: 4),
      Text('($count ${count == 1 ? 'rating' : 'ratings'})',
          style:
              const TextStyle(color: CrewConstants.textSecondary, fontSize: 12)),
    ]);
  }

  Widget _buildAvatar(String? photoUrl) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: CrewConstants.primary, width: 3),
              image: DecorationImage(
                  image: NetworkImage(photoUrl), fit: BoxFit.cover)));
    }
    return Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
            color: CrewConstants.secondary,
            shape: BoxShape.circle,
            border: Border.all(color: CrewConstants.primary, width: 3)),
        child:
            const Icon(Icons.person, color: CrewConstants.primary, size: 48));
  }

  Widget _infoRow(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, color: CrewConstants.primary, size: 18),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: CrewConstants.textPrimary, fontSize: 14)))
      ]));

  Widget _sectionCard(String title, IconData icon, List<Widget> children) {
    return Container(
        width: double.infinity,
        decoration: BoxDecoration(
            color: CrewConstants.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CrewConstants.border)),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: CrewConstants.primary, size: 18),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    color: CrewConstants.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2))
          ]),
          const SizedBox(height: 10),
          ...children
        ]));
  }
}
