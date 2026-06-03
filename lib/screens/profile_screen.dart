// Profile screen — view/edit own profile, certifications (+ expiry reminders),
// availability, crew history with real endorsements / job offers / ratings.
//
// SQL MIGRATIONS (see supabase_migrations.sql for full DDL incl. RLS):
//   -- endorsements
//   create table public.endorsements (
//     id uuid primary key default gen_random_uuid(),
//     from_user_id uuid references auth.users(id),
//     to_user_id   uuid references auth.users(id),
//     match_id     uuid references public.matches(id),
//     content      text,
//     created_at   timestamptz default now()
//   );
//   -- ratings (1-5)
//   create table public.ratings (
//     id uuid primary key default gen_random_uuid(),
//     from_user_id uuid references auth.users(id),
//     to_user_id   uuid references auth.users(id),
//     match_id     uuid references public.matches(id),
//     score        int check (score between 1 and 5),
//     created_at   timestamptz default now(),
//     unique (from_user_id, match_id)
//   );
//   -- availability
//   alter table public.profiles add column if not exists availability_status text;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../crew_constants.dart';
import '../error_helper.dart';
import 'chat_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  String? _role;
  bool _loading = true;
  bool _editing = false;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _bioController = TextEditingController();
  final _yearsController = TextEditingController();
  String _selectedExperience = 'apprentice_1st';
  String _selectedTradeType = 'Welder';
  String? _selectedAvailability;

  List<Map<String, dynamic>> _certifications = [];
  List<Map<String, dynamic>> _crewHistory = [];

  double? _myAvgRating;
  int _myRatingCount = 0;
  final Set<String> _ratedMatchIds = {};

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) {
        setState(() => _loading = false);
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }
    try {
      final userRes =
          await _client.from('users').select('role').eq('id', userId).maybeSingle();
      final profileRes = await _client
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      final certRes = await _client
          .from('certifications')
          .select()
          .eq('user_id', userId)
          .order('created_at');

      // Ratings I've received (average) and matches I've already rated.
      final recvRes =
          await _client.from('ratings').select('score').eq('to_user_id', userId);
      final givenRes = await _client
          .from('ratings')
          .select('match_id')
          .eq('from_user_id', userId);

      final history = await _loadCrewHistory(userId);

      final recv = (recvRes as List).cast<Map<String, dynamic>>();
      double? avg;
      if (recv.isNotEmpty) {
        final sum = recv.fold<int>(
            0, (acc, r) => acc + ((r['score'] as num?)?.toInt() ?? 0));
        avg = sum / recv.length;
      }

      if (!mounted) return;
      setState(() {
        _role = userRes?['role'];
        _profile = profileRes;
        _selectedAvailability = profileRes?['availability_status'];
        _certifications = (certRes as List).cast<Map<String, dynamic>>();
        _crewHistory = history;
        _myAvgRating = avg;
        _myRatingCount = recv.length;
        _ratedMatchIds
          ..clear()
          ..addAll((givenRes as List)
              .map((r) => r['match_id']?.toString())
              .whereType<String>());
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppFeedback.showError(context, e, fallback: 'Could not load your profile');
    }
  }

  /// Batched crew-history load (no N+1): one matches query + one users query.
  Future<List<Map<String, dynamic>>> _loadCrewHistory(String userId) async {
    final res = await _client
        .from('matches')
        .select()
        .or('journeyman_id.eq.$userId,helper_id.eq.$userId')
        .order('matched_at', ascending: false);
    final matches = (res as List).cast<Map<String, dynamic>>();
    if (matches.isEmpty) return [];

    final otherIds = <String>{};
    for (final m in matches) {
      final otherId =
          m['journeyman_id'] == userId ? m['helper_id'] : m['journeyman_id'];
      if (otherId != null) otherIds.add(otherId.toString());
    }
    if (otherIds.isEmpty) return [];

    final usersRes = await _client
        .from('users')
        .select('id, email, role, profiles(full_name, location_text, trade_type)')
        .inFilter('id', otherIds.toList());
    final byId = <String, Map<String, dynamic>>{};
    for (final u in (usersRes as List).cast<Map<String, dynamic>>()) {
      byId[u['id'].toString()] = u;
    }

    final history = <Map<String, dynamic>>[];
    for (final m in matches) {
      final otherId =
          (m['journeyman_id'] == userId ? m['helper_id'] : m['journeyman_id'])
              ?.toString();
      if (otherId == null) continue;
      final u = byId[otherId];
      final profile = u?['profiles'] as Map<String, dynamic>?;
      history.add({
        'match_id': m['id'],
        'matched_at': m['matched_at'],
        'other_id': otherId,
        'other_name': profile?['full_name'] ?? u?['email'] ?? 'Unknown',
        'other_role': u?['role'] ?? '',
        'other_location': profile?['location_text'] ?? '',
      });
    }
    return history;
  }

  Future<void> _uploadProfilePhoto() async {
    try {
      final picked = await _picker.pickImage(
          source: ImageSource.gallery, maxWidth: 800, imageQuality: 80);
      if (picked == null) return;

      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await picked.readAsBytes();

      await _client.storage.from('profile-photos').uploadBinary(fileName, bytes,
          fileOptions:
              const FileOptions(contentType: 'image/jpeg', upsert: true));
      final url =
          _client.storage.from('profile-photos').getPublicUrl(fileName);

      await _client
          .from('profiles')
          .update({'profile_photo_url': url}).eq('user_id', userId);
      await _loadProfile();
      if (!mounted) return;
      AppFeedback.showSuccess(context, 'Profile photo updated!');
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, e, fallback: 'Could not upload photo');
    }
  }

  void _startEditing() {
    _nameController.text = _profile?['full_name'] ?? '';
    _phoneController.text = _profile?['phone'] ?? '';
    _locationController.text = _profile?['location_text'] ?? '';
    _bioController.text = _profile?['bio'] ?? '';
    _yearsController.text = (_profile?['years_in_field'] ?? 0).toString();
    _selectedExperience = _profile?['experience_level'] ?? 'apprentice_1st';
    if (_selectedExperience == 'master') _selectedExperience = 'journeyman';
    final t = _profile?['trade_type'] ?? 'Welder';
    _selectedTradeType = CrewConstants.tradeTypes.contains(t)
        ? t
        : (CrewConstants.tradeTypes
                .where((tt) => tt.toLowerCase() == t.toLowerCase())
                .isNotEmpty
            ? CrewConstants.tradeTypes
                .firstWhere((tt) => tt.toLowerCase() == t.toLowerCase())
            : 'Welder');
    _selectedAvailability = _profile?['availability_status'];
    setState(() => _editing = true);
  }

  Future<void> _saveProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    if (_nameController.text.trim().isEmpty) {
      AppFeedback.showError(context, 'Please enter your name',
          fallback: 'Please enter your name');
      return;
    }
    try {
      await _client.from('profiles').upsert({
        'user_id': userId,
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'location_text': _locationController.text.trim(),
        'bio': _bioController.text.trim(),
        'experience_level': _selectedExperience,
        'trade_type': _selectedTradeType,
        'years_in_field': int.tryParse(_yearsController.text) ?? 0,
        'availability_status': _selectedAvailability,
      }, onConflict: 'user_id');
      if (!mounted) return;
      AppFeedback.showSuccess(context, 'Profile saved!');
      await _loadProfile();
      if (!mounted) return;
      setState(() => _editing = false);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, e, fallback: 'Could not save profile');
    }
  }

  void _showAddCertDialog() {
    final nameCtrl = TextEditingController();
    DateTime? expiry;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: CrewConstants.surface,
          title: const Text('Add Certification',
              style: TextStyle(color: CrewConstants.textPrimary, fontSize: 18)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: nameCtrl,
                maxLength: 60,
                style: const TextStyle(color: CrewConstants.textPrimary),
                decoration: const InputDecoration(
                    hintText: 'e.g. CSTS-2020, H2S Alive', counterText: '')),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now().add(const Duration(days: 365)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2035));
                if (picked != null) setD(() => expiry = picked);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: CrewConstants.background,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: CrewConstants.border)),
                child: Row(children: [
                  const Icon(Icons.calendar_today,
                      color: CrewConstants.textSecondary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                      expiry != null
                          ? '${expiry!.year}-${expiry!.month.toString().padLeft(2, '0')}-${expiry!.day.toString().padLeft(2, '0')}'
                          : 'Tap to set expiry date',
                      style: TextStyle(
                          color: expiry != null
                              ? CrewConstants.textPrimary
                              : CrewConstants.textSecondary,
                          fontSize: 14))
                ]),
              ),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CANCEL',
                    style: TextStyle(color: CrewConstants.textSecondary))),
            TextButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final userId = _client.auth.currentUser?.id;
                  if (userId == null) return;
                  try {
                    await _client.from('certifications').insert({
                      'user_id': userId,
                      'name': nameCtrl.text.trim(),
                      'expiry_date': expiry?.toIso8601String().split('T')[0],
                      'status': 'pending'
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _loadProfile();
                    if (!mounted) return;
                    AppFeedback.showSuccess(context, 'Certification added!');
                  } catch (e) {
                    if (!mounted) return;
                    AppFeedback.showError(context, e,
                        fallback: 'Could not add certification');
                  }
                },
                child: const Text('ADD',
                    style: TextStyle(color: CrewConstants.primary))),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadCertPhoto(String certId) async {
    try {
      final picked =
          await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
      if (picked == null) return;
      final userId = _client.auth.currentUser?.id;
      final fileName =
          '${userId}_${certId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await picked.readAsBytes();
      await _client.storage.from('certifications').uploadBinary(fileName, bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'));
      final url = _client.storage.from('certifications').getPublicUrl(fileName);
      await _client
          .from('certifications')
          .update({'photo_url': url}).eq('id', certId);
      await _loadProfile();
      if (!mounted) return;
      AppFeedback.showSuccess(context, 'Photo uploaded!');
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, e, fallback: 'Could not upload photo');
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
                      child: Text('Failed to load image',
                          style:
                              TextStyle(color: CrewConstants.textSecondary))))),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CLOSE',
                  style: TextStyle(color: CrewConstants.primary))),
        ]),
      ),
    );
  }

  Future<void> _deleteCert(String certId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CrewConstants.surface,
        title: const Text('Delete certification?',
            style: TextStyle(color: CrewConstants.textPrimary, fontSize: 18)),
        content: const Text('This cannot be undone.',
            style: TextStyle(color: CrewConstants.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCEL',
                  style: TextStyle(color: CrewConstants.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('DELETE',
                  style: TextStyle(color: CrewConstants.danger))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _client.from('certifications').delete().eq('id', certId);
      await _loadProfile();
      if (!mounted) return;
      AppFeedback.showSuccess(context, 'Certification deleted');
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, e, fallback: 'Could not delete');
    }
  }

  // --------------------------------------------------------------------------
  // Endorsements (real)
  // --------------------------------------------------------------------------
  void _showEndorsementDialog(Map<String, dynamic> person) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CrewConstants.surface,
        title: Text('Endorse ${person['other_name']}',
            style:
                const TextStyle(color: CrewConstants.textPrimary, fontSize: 18)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Leave an endorsement for ${person['other_name']}.',
              style: const TextStyle(
                  color: CrewConstants.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
              controller: controller,
              maxLines: 3,
              maxLength: 500,
              style: const TextStyle(
                  color: CrewConstants.textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                  hintText: 'Hard worker, shows up on time...')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL',
                  style: TextStyle(color: CrewConstants.textSecondary))),
          TextButton(
              onPressed: () => _submitEndorsement(ctx, person, controller.text),
              child: const Text('SEND',
                  style: TextStyle(color: CrewConstants.primary))),
        ],
      ),
    );
  }

  Future<void> _submitEndorsement(
      BuildContext dialogCtx, Map<String, dynamic> person, String text) async {
    final content = text.trim();
    if (content.isEmpty) {
      AppFeedback.showError(dialogCtx, 'Write something first',
          fallback: 'Write something first');
      return;
    }
    final me = _client.auth.currentUser?.id;
    final otherId = person['other_id'];
    if (me == null || otherId == null) return;
    try {
      await _client.from('endorsements').insert({
        'from_user_id': me,
        'to_user_id': otherId,
        'match_id': person['match_id'],
        'content': content,
      });
      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
      if (!mounted) return;
      AppFeedback.showSuccess(
          context, 'Endorsement sent to ${person['other_name']}!');
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, e, fallback: 'Could not send endorsement');
    }
  }

  // --------------------------------------------------------------------------
  // Offer work (real): pick one of my active jobs -> ensure match -> open chat
  // --------------------------------------------------------------------------
  Future<void> _showOfferWorkDialog(Map<String, dynamic> person) async {
    final me = _client.auth.currentUser?.id;
    if (me == null) return;
    List<Map<String, dynamic>> jobs;
    try {
      final res = await _client
          .from('jobs')
          .select('id, title, hourly_rate')
          .eq('journeyman_id', me)
          .eq('is_active', true)
          .order('created_at', ascending: false);
      jobs = (res as List).cast<Map<String, dynamic>>();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, e, fallback: 'Could not load your jobs');
      return;
    }
    if (!mounted) return;
    if (jobs.isEmpty) {
      AppFeedback.showInfo(
          context, 'You have no active jobs to offer. Post a job first.');
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CrewConstants.surface,
        title: Text('Offer work to ${person['other_name']}',
            style:
                const TextStyle(color: CrewConstants.textPrimary, fontSize: 18)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: jobs.map((job) {
              final rate = job['hourly_rate'];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(Icons.work, color: CrewConstants.primary, size: 20),
                title: Text(job['title'] ?? 'Untitled',
                    style:
                        const TextStyle(color: CrewConstants.textPrimary, fontSize: 14)),
                subtitle: rate != null
                    ? Text('\$$rate/hr',
                        style: const TextStyle(
                            color: CrewConstants.textSecondary, fontSize: 12))
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _offerJob(person, job);
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL',
                  style: TextStyle(color: CrewConstants.textSecondary))),
        ],
      ),
    );
  }

  Future<void> _offerJob(
      Map<String, dynamic> person, Map<String, dynamic> job) async {
    final me = _client.auth.currentUser?.id;
    final otherId = person['other_id'];
    if (me == null || otherId == null) return;
    try {
      String matchId;
      final existing = await _client
          .from('matches')
          .select('id')
          .eq('journeyman_id', me)
          .eq('helper_id', otherId)
          .maybeSingle();
      if (existing != null) {
        matchId = existing['id'].toString();
        await _client
            .from('matches')
            .update({'job_id': job['id']}).eq('id', matchId);
      } else {
        final inserted = await _client
            .from('matches')
            .insert({
              'journeyman_id': me,
              'helper_id': otherId,
              'job_id': job['id'],
            })
            .select('id')
            .single();
        matchId = inserted['id'].toString();
      }
      if (!mounted) return;
      AppFeedback.showSuccess(context, 'Job offered — opening chat');
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ChatScreen(
                  matchId: matchId,
                  otherUserName: (person['other_name'] ?? 'Crew').toString(),
                  otherUserRole:
                      (person['other_role'] ?? 'helper').toString())));
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, e, fallback: 'Could not send offer');
    }
  }

  // --------------------------------------------------------------------------
  // Ratings
  // --------------------------------------------------------------------------
  bool _canRate(Map<String, dynamic> person) {
    final matchId = person['match_id']?.toString();
    if (person['other_id'] == null || matchId == null) return false;
    if (_ratedMatchIds.contains(matchId)) return false;
    final days = CrewConstants.daysUntil(person['matched_at']?.toString());
    if (days == null) return false;
    return -days >= CrewConstants.minRatingDays; // match is 7+ days old
  }

  void _showRatingDialog(Map<String, dynamic> person) {
    int score = 5;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: CrewConstants.surface,
          title: Text('Rate ${person['other_name']}',
              style: const TextStyle(
                  color: CrewConstants.textPrimary, fontSize: 18)),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                5,
                (i) => IconButton(
                      icon: Icon(i < score ? Icons.star : Icons.star_border,
                          color: CrewConstants.warning, size: 28),
                      onPressed: () => setD(() => score = i + 1),
                    )),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CANCEL',
                    style: TextStyle(color: CrewConstants.textSecondary))),
            TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _submitRating(person, score);
                },
                child: const Text('SUBMIT',
                    style: TextStyle(color: CrewConstants.primary))),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRating(Map<String, dynamic> person, int score) async {
    final me = _client.auth.currentUser?.id;
    final otherId = person['other_id'];
    final matchId = person['match_id'];
    if (me == null || otherId == null || matchId == null) return;
    try {
      await _client.from('ratings').insert({
        'from_user_id': me,
        'to_user_id': otherId,
        'match_id': matchId,
        'score': score,
      });
      if (!mounted) return;
      setState(() => _ratedMatchIds.add(matchId.toString()));
      AppFeedback.showSuccess(context, 'Rating submitted');
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, e, fallback: 'Could not submit rating');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    _yearsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(title: const Text('PROFILE'), actions: [
          if (_editing)
            TextButton(
                onPressed: () => setState(() => _editing = false),
                child: const Text('Cancel',
                    style: TextStyle(color: CrewConstants.textSecondary)))
          else
            TextButton(
                onPressed: () async {
                  await _client.auth.signOut();
                  // The global auth listener in main.dart handles routing to
                  // /login on signedOut.
                },
                child: const Text('Sign Out',
                    style:
                        TextStyle(color: CrewConstants.danger, fontSize: 13))),
        ]),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: CrewConstants.primary))
            : _editing
                ? _buildEditMode()
                : _buildViewMode(),
      ),
    );
  }

  Widget _buildViewMode() {
    final name = _profile?['full_name'] ?? 'No Name';
    final bio = _profile?['bio'] ?? '';
    final location = _profile?['location_text'] ?? '';
    final experience = _profile?['experience_level'] ?? '';
    final phone = _profile?['phone'] ?? '';
    final email = _client.auth.currentUser?.email ?? '';
    final tradeType = _profile?['trade_type'] ?? 'Welder';
    final yearsInField = _profile?['years_in_field'] ?? 0;

    final expiringCerts = _certifications
        .where((c) => CrewConstants.certNeedsAttention(c['expiry_date']?.toString()))
        .toList();

    return RefreshIndicator(
      color: CrewConstants.primary,
      onRefresh: _loadProfile,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          if (expiringCerts.isNotEmpty) _buildCertExpiryBanner(expiringCerts),
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
                      _buildProfilePhoto(),
                      const SizedBox(height: 14),
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
                                  color: _role == 'journeyman'
                                      ? CrewConstants.secondary
                                      : CrewConstants.primary.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4)),
                              child: Text((_role ?? 'helper').toUpperCase(),
                                  style: TextStyle(
                                      color: _role == 'journeyman'
                                          ? CrewConstants.accentBlue
                                          : CrewConstants.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2))),
                          if (_selectedAvailability != null)
                            _availabilityChip(_selectedAvailability),
                        ],
                      ),
                      if (_myAvgRating != null) ...[
                        const SizedBox(height: 8),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.star,
                              color: CrewConstants.warning, size: 16),
                          const SizedBox(width: 4),
                          Text(_myAvgRating!.toStringAsFixed(1),
                              style: const TextStyle(
                                  color: CrewConstants.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(width: 4),
                          Text(
                              '($_myRatingCount ${_myRatingCount == 1 ? 'rating' : 'ratings'})',
                              style: const TextStyle(
                                  color: CrewConstants.textSecondary,
                                  fontSize: 12)),
                        ]),
                      ],
                    ])),
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      if (location.isNotEmpty)
                        _infoRow(Icons.location_on, location),
                      _infoRow(Icons.build, tradeType),
                      if (experience.isNotEmpty)
                        _infoRow(
                            Icons.work, CrewConstants.expToLabel(experience)),
                      if (yearsInField > 0)
                        _infoRow(Icons.calendar_today,
                            '$yearsInField years in the field'),
                      if (phone.isNotEmpty) _infoRow(Icons.phone, phone),
                      _infoRow(Icons.email, email),
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: CrewConstants.background,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: CrewConstants.border)),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('ABOUT ME',
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
                                          height: 1.5))
                                ]))
                      ],
                    ])),
              ])),
          const SizedBox(height: 12),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                  onPressed: _startEditing,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('EDIT PROFILE'))),
          const SizedBox(height: 16),
          Container(
              width: double.infinity,
              decoration: BoxDecoration(
                  color: CrewConstants.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CrewConstants.border)),
              padding: const EdgeInsets.all(16),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _statItem('${_certifications.length}', 'Certs'),
                Container(width: 1, height: 40, color: CrewConstants.border),
                _statItem(_myAvgRating != null
                    ? _myAvgRating!.toStringAsFixed(1)
                    : '—', 'Rating'),
                Container(width: 1, height: 40, color: CrewConstants.border),
                _statItem('${_crewHistory.length}', 'Crew'),
              ])),
          const SizedBox(height: 16),
          _buildAvailabilityCard(),
          const SizedBox(height: 16),
          _sectionCard(
              _role == 'journeyman'
                  ? 'CREW I\'VE HIRED'
                  : 'PEOPLE I\'VE WORKED FOR',
              Icons.group,
              _crewHistory.isEmpty
                  ? [
                      const Text('No crew history yet.',
                          style: TextStyle(
                              color: CrewConstants.textSecondary, fontSize: 13))
                    ]
                  : _crewHistory.map(_buildCrewHistoryItem).toList()),
          const SizedBox(height: 12),
          _buildCertificationsCard(),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Widget _buildCertExpiryBanner(List<Map<String, dynamic>> certs) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: CrewConstants.warning.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: CrewConstants.warning)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Icon(Icons.warning_amber_rounded,
              color: CrewConstants.warning, size: 18),
          SizedBox(width: 8),
          Text('CERTIFICATIONS NEED ATTENTION',
              style: TextStyle(
                  color: CrewConstants.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
        ]),
        const SizedBox(height: 8),
        ...certs.map((c) {
          final expiry = c['expiry_date']?.toString();
          final label = CrewConstants.certExpiryLabel(expiry);
          final color = CrewConstants.certExpiryColor(expiry);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('${c['name'] ?? 'Certification'} — $label',
                      style: TextStyle(color: color, fontSize: 12))),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _buildCrewHistoryItem(Map<String, dynamic> p) {
    final isJourneyman = _role == 'journeyman';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: CrewConstants.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: CrewConstants.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: CrewConstants.secondary,
                    shape: BoxShape.circle,
                    border: Border.all(color: CrewConstants.primary, width: 1.5)),
                child: const Icon(Icons.person,
                    color: CrewConstants.primary, size: 18)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(p['other_name'],
                      style: const TextStyle(
                          color: CrewConstants.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  Row(children: [
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                            color: p['other_role'] == 'journeyman'
                                ? CrewConstants.secondary
                                : CrewConstants.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(3)),
                        child: Text(
                            (p['other_role'] ?? '').toString().toUpperCase(),
                            style: TextStyle(
                                color: p['other_role'] == 'journeyman'
                                    ? CrewConstants.accentBlue
                                    : CrewConstants.primary,
                                fontSize: 9,
                                fontWeight: FontWeight.w700)))
                  ]),
                ])),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
                onPressed: () => _showEndorsementDialog(p),
                icon: const Icon(Icons.thumb_up, size: 14),
                label: const Text('ENDORSE', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                    foregroundColor: CrewConstants.success,
                    side: const BorderSide(color: CrewConstants.success),
                    minimumSize: const Size(0, 34))),
            if (_canRate(p))
              OutlinedButton.icon(
                  onPressed: () => _showRatingDialog(p),
                  icon: const Icon(Icons.star, size: 14),
                  label: const Text('RATE', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: CrewConstants.warning,
                      side: const BorderSide(color: CrewConstants.warning),
                      minimumSize: const Size(0, 34))),
            if (isJourneyman)
              OutlinedButton.icon(
                  onPressed: () => _showOfferWorkDialog(p),
                  icon: const Icon(Icons.work, size: 14),
                  label:
                      const Text('OFFER WORK', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: CrewConstants.primary,
                      side: const BorderSide(color: CrewConstants.primary),
                      minimumSize: const Size(0, 34))),
          ]),
        ]),
      ),
    );
  }

  Widget _buildCertificationsCard() {
    return _sectionCard('MY CERTIFICATIONS', Icons.verified, [
      ..._certifications.map((c) {
        final expiry = c['expiry_date']?.toString();
        final expiryLabel = CrewConstants.certExpiryLabel(expiry);
        final expiryColor = CrewConstants.certExpiryColor(expiry);
        final verified = c['status'] == 'verified';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: CrewConstants.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CrewConstants.border)),
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
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
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
                    constraints:
                        const BoxConstraints(minWidth: 30, minHeight: 30))
              else
                IconButton(
                    icon: const Icon(Icons.camera_alt,
                        color: CrewConstants.primary, size: 18),
                    onPressed: () => _uploadCertPhoto(c['id'].toString()),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 30, minHeight: 30)),
              IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: CrewConstants.danger, size: 18),
                  onPressed: () => _deleteCert(c['id'].toString()),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 30, minHeight: 30)),
            ]),
          ),
        );
      }),
      const SizedBox(height: 8),
      OutlinedButton.icon(
          onPressed: _showAddCertDialog,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('ADD CERTIFICATION', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
              foregroundColor: CrewConstants.primary,
              side: const BorderSide(color: CrewConstants.primary),
              minimumSize: const Size(double.infinity, 40))),
    ]);
  }

  Widget _buildAvailabilityCard() {
    final status = _selectedAvailability;
    final color = CrewConstants.availabilityColor(status);
    final now = DateTime.now();
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return _sectionCard('AVAILABILITY', Icons.event_available, [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) {
          final isToday = (i + 1) == now.weekday;
          return Column(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: isToday ? CrewConstants.primary : color,
                      width: isToday ? 2 : 1)),
              child: Center(
                  child: Text(letters[i],
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700))),
            ),
          ]);
        }),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(CrewConstants.availabilityLabel(status),
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 4),
      const Text('Set your status in Edit Profile.',
          style: TextStyle(color: CrewConstants.textSecondary, fontSize: 11)),
    ]);
  }

  Widget _availabilityChip(String? status) {
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

  Widget _buildEditMode() {
    return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Center(child: _buildEditProfilePhoto()),
          const SizedBox(height: 6),
          const Text('Tap photo to change',
              style: TextStyle(color: CrewConstants.textSecondary, fontSize: 11)),
          const SizedBox(height: 24),
          _buildField('Full Name', _nameController, maxLength: 50),
          _buildField('Phone', _phoneController,
              type: TextInputType.phone, maxLength: 20),
          _buildField('Location (City, Province)', _locationController,
              maxLength: 100),
          _buildField('Years in the Field', _yearsController,
              type: TextInputType.number, maxLength: 2),
          const SizedBox(height: 16),
          _buildAvailabilitySelector(),
          const SizedBox(height: 16),
          const Align(
              alignment: Alignment.centerLeft,
              child: Text('TRADE TYPE',
                  style: TextStyle(
                      color: CrewConstants.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2))),
          const SizedBox(height: 8),
          Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                  color: CrewConstants.background,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: CrewConstants.border)),
              child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                value: CrewConstants.tradeTypes.contains(_selectedTradeType)
                    ? _selectedTradeType
                    : CrewConstants.tradeTypes[0],
                dropdownColor: CrewConstants.surface,
                style: const TextStyle(
                    color: CrewConstants.textPrimary, fontSize: 15),
                isExpanded: true,
                items: CrewConstants.tradeTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedTradeType = v ?? 'Welder'),
              ))),
          const SizedBox(height: 16),
          const Align(
              alignment: Alignment.centerLeft,
              child: Text('EXPERIENCE LEVEL',
                  style: TextStyle(
                      color: CrewConstants.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2))),
          const SizedBox(height: 8),
          Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                  color: CrewConstants.background,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: CrewConstants.border)),
              child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                value: _selectedExperience,
                dropdownColor: CrewConstants.surface,
                style: const TextStyle(
                    color: CrewConstants.textPrimary, fontSize: 15),
                isExpanded: true,
                items: CrewConstants.experienceLevels
                    .map((e) =>
                        DropdownMenuItem(value: e['value'], child: Text(e['label']!)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _selectedExperience = v ?? 'apprentice_1st'),
              ))),
          const SizedBox(height: 16),
          _buildField('Bio (Tell people about yourself)', _bioController,
              maxLines: 4, maxLength: 500),
          const SizedBox(height: 24),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: _saveProfile, child: const Text('SAVE PROFILE'))),
          const SizedBox(height: 32),
        ]));
  }

  Widget _buildAvailabilitySelector() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('AVAILABILITY',
          style: TextStyle(
              color: CrewConstants.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: CrewConstants.availabilityStatuses.map((s) {
          final selected = _selectedAvailability == s;
          final color = CrewConstants.availabilityColor(s);
          return GestureDetector(
            onTap: () => setState(() => _selectedAvailability = s),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: selected
                      ? color.withOpacity(0.2)
                      : CrewConstants.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: selected ? color : CrewConstants.border)),
              child: Text(CrewConstants.availabilityLabel(s),
                  style: TextStyle(
                      color: selected ? color : CrewConstants.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          );
        }).toList(),
      ),
    ]);
  }

  Widget _buildProfilePhoto() {
    final photoUrl = _profile?['profile_photo_url'];
    return GestureDetector(
      onTap: _uploadProfilePhoto,
      child: Stack(children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: CrewConstants.secondary,
            shape: BoxShape.circle,
            border: Border.all(color: CrewConstants.primary, width: 3),
            image: photoUrl != null && photoUrl.toString().isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(photoUrl), fit: BoxFit.cover)
                : null,
          ),
          child: photoUrl == null || photoUrl.toString().isEmpty
              ? const Icon(Icons.person, color: CrewConstants.primary, size: 52)
              : null,
        ),
        Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                  color: CrewConstants.primary, shape: BoxShape.circle),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
            )),
      ]),
    );
  }

  Widget _buildEditProfilePhoto() {
    final photoUrl = _profile?['profile_photo_url'];
    return GestureDetector(
      onTap: _uploadProfilePhoto,
      child: Stack(children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: CrewConstants.secondary,
            shape: BoxShape.circle,
            border: Border.all(color: CrewConstants.primary, width: 3),
            image: photoUrl != null && photoUrl.toString().isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(photoUrl), fit: BoxFit.cover)
                : null,
          ),
          child: photoUrl == null || photoUrl.toString().isEmpty
              ? const Icon(Icons.person, color: CrewConstants.primary, size: 48)
              : null,
        ),
        Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                  color: CrewConstants.primary, shape: BoxShape.circle),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
            )),
      ]),
    );
  }

  Widget _buildField(String label, TextEditingController c,
      {TextInputType type = TextInputType.text,
      int maxLines = 1,
      int? maxLength}) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextField(
            controller: c,
            keyboardType: type,
            maxLines: maxLines,
            maxLength: maxLength,
            style:
                const TextStyle(color: CrewConstants.textPrimary, fontSize: 15),
            decoration: InputDecoration(
                labelText: label,
                counterText: maxLength != null ? '' : null)));
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

  Widget _statItem(String value, String label) => Column(children: [
        Text(value,
            style: const TextStyle(
                color: CrewConstants.primary,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                color: CrewConstants.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600))
      ]);

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
