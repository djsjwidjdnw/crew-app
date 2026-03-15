import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../crew_constants.dart';

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

  List<Map<String, dynamic>> _certifications = [];
  List<Map<String, dynamic>> _crewHistory = [];

  @override
  void initState() { super.initState(); _loadProfile(); }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) { setState(() => _loading = false); return; }
    try {
      final userRes = await Supabase.instance.client.from('users').select('role').eq('id', userId).maybeSingle();
      _role = userRes?['role'];
      final profileRes = await Supabase.instance.client.from('profiles').select().eq('user_id', userId).maybeSingle();
      _profile = profileRes;

      // Load real certifications
      final certRes = await Supabase.instance.client.from('certifications').select().eq('user_id', userId).order('created_at');
      _certifications = (certRes as List).cast<Map<String, dynamic>>();

      await _loadCrewHistory(userId);
    } catch (e) { debugPrint('Error loading profile: $e'); }
    setState(() => _loading = false);
  }

  Future<void> _loadCrewHistory(String userId) async {
    try {
      final res = await Supabase.instance.client.from('matches').select().or('journeyman_id.eq.$userId,helper_id.eq.$userId').order('matched_at', ascending: false);
      final matches = (res as List).cast<Map<String, dynamic>>();
      List<Map<String, dynamic>> history = [];
      for (final match in matches) {
        final otherId = match['journeyman_id'] == userId ? match['helper_id'] : match['journeyman_id'];
        try {
          final userRes = await Supabase.instance.client.from('users').select('id, email, role').eq('id', otherId).maybeSingle();
          if (userRes == null) continue;
          final profileRes = await Supabase.instance.client.from('profiles').select('full_name, location_text, trade_type').eq('user_id', otherId).maybeSingle();
          history.add({'match_id': match['id'], 'other_name': profileRes?['full_name'] ?? userRes['email'] ?? 'Unknown', 'other_role': userRes['role'] ?? '', 'other_location': profileRes?['location_text'] ?? ''});
        } catch (e) {}
      }
      _crewHistory = history;
    } catch (e) { _crewHistory = []; }
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
    _selectedTradeType = CrewConstants.tradeTypes.contains(t) ? t : (CrewConstants.tradeTypes.where((tt) => tt.toLowerCase() == t.toLowerCase()).isNotEmpty ? CrewConstants.tradeTypes.firstWhere((tt) => tt.toLowerCase() == t.toLowerCase()) : 'Welder');
    setState(() => _editing = true);
  }

  Future<void> _saveProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await Supabase.instance.client.from('profiles').upsert({
        'user_id': userId, 'full_name': _nameController.text.trim(), 'phone': _phoneController.text.trim(),
        'location_text': _locationController.text.trim(), 'bio': _bioController.text.trim(),
        'experience_level': _selectedExperience, 'trade_type': _selectedTradeType,
        'years_in_field': int.tryParse(_yearsController.text) ?? 0,
      }, onConflict: 'user_id');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved!'), backgroundColor: Color(0xFF22c55e)));
      await _loadProfile();
      setState(() => _editing = false);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFef4444)));
    }
  }

  void _showAddCertDialog() {
    final nameCtrl = TextEditingController();
    DateTime? expiry;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
      backgroundColor: const Color(0xFF111827),
      title: const Text('Add Certification', style: TextStyle(color: Color(0xFFF0F4FF), fontSize: 18)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, style: const TextStyle(color: Color(0xFFF0F4FF)), decoration: const InputDecoration(hintText: 'e.g. CSTS-2020, H2S Alive')),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(context: ctx, initialDate: DateTime.now().add(const Duration(days: 365)), firstDate: DateTime.now(), lastDate: DateTime(2035));
            if (picked != null) setD(() => expiry = picked);
          },
          child: Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF0A0E1A), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFF1e2d45))),
            child: Row(children: [const Icon(Icons.calendar_today, color: Color(0xFF8896b0), size: 16), const SizedBox(width: 8),
              Text(expiry != null ? '${expiry!.year}-${expiry!.month.toString().padLeft(2, '0')}-${expiry!.day.toString().padLeft(2, '0')}' : 'Tap to set expiry date', style: TextStyle(color: expiry != null ? const Color(0xFFF0F4FF) : const Color(0xFF8896b0), fontSize: 14))])),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: Color(0xFF8896b0)))),
        TextButton(onPressed: () async {
          if (nameCtrl.text.trim().isEmpty) return;
          final userId = Supabase.instance.client.auth.currentUser?.id;
          if (userId == null) return;
          try {
            await Supabase.instance.client.from('certifications').insert({
              'user_id': userId, 'name': nameCtrl.text.trim(),
              'expiry_date': expiry?.toIso8601String().split('T')[0], 'status': 'pending',
            });
            Navigator.pop(ctx);
            _loadProfile();
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Certification added!'), backgroundColor: Color(0xFF22c55e)));
          } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFef4444))); }
        }, child: const Text('ADD', style: TextStyle(color: Color(0xFFFF6B35)))),
      ],
    )));
  }

  Future<void> _uploadCertPhoto(String certId) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
      if (picked == null) return;

      final userId = Supabase.instance.client.auth.currentUser?.id;
      final fileName = '${userId}_${certId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await picked.readAsBytes();

      await Supabase.instance.client.storage.from('certifications').uploadBinary(fileName, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));
      final url = Supabase.instance.client.storage.from('certifications').getPublicUrl(fileName);

      await Supabase.instance.client.from('certifications').update({'photo_url': url}).eq('id', certId);
      _loadProfile();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo uploaded!'), backgroundColor: Color(0xFF22c55e)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload error: $e'), backgroundColor: const Color(0xFFef4444)));
    }
  }

  void _viewCertPhoto(String url) {
    showDialog(context: context, builder: (ctx) => Dialog(
      backgroundColor: const Color(0xFF111827),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), child: Image.network(url, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Padding(padding: EdgeInsets.all(40), child: Text('Failed to load image', style: TextStyle(color: Color(0xFF8896b0)))))),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CLOSE', style: TextStyle(color: Color(0xFFFF6B35)))),
      ]),
    ));
  }

  Future<void> _deleteCert(String certId) async {
    try {
      await Supabase.instance.client.from('certifications').delete().eq('id', certId);
      _loadProfile();
    } catch (e) {}
  }

  void _showEndorsementDialog(Map<String, dynamic> person) {
    final controller = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF111827),
      title: Text('Endorse ${person['other_name']}', style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 18)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Leave an endorsement for ${person['other_name']}.', style: const TextStyle(color: Color(0xFF8896b0), fontSize: 13)),
        const SizedBox(height: 12),
        TextField(controller: controller, maxLines: 3, style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 14), decoration: const InputDecoration(hintText: 'Hard worker, shows up on time...')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: Color(0xFF8896b0)))),
        TextButton(onPressed: () { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Endorsement sent to ${person['other_name']}!'), backgroundColor: const Color(0xFF22c55e))); }, child: const Text('SEND', style: TextStyle(color: Color(0xFFFF6B35)))),
      ],
    ));
  }

  @override
  void dispose() { _nameController.dispose(); _phoneController.dispose(); _locationController.dispose(); _bioController.dispose(); _yearsController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PROFILE'), actions: [
        if (_editing) TextButton(onPressed: () => setState(() => _editing = false), child: const Text('Cancel', style: TextStyle(color: Color(0xFF8896b0))))
        else TextButton(onPressed: () async { await Supabase.instance.client.auth.signOut(); if (mounted) Navigator.pushReplacementNamed(context, '/login'); }, child: const Text('Sign Out', style: TextStyle(color: Color(0xFFef4444), fontSize: 13))),
      ]),
      body: _loading ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35))) : _editing ? _buildEditMode() : _buildViewMode(),
    );
  }

  Widget _buildViewMode() {
    final name = _profile?['full_name'] ?? 'No Name';
    final bio = _profile?['bio'] ?? '';
    final location = _profile?['location_text'] ?? '';
    final experience = _profile?['experience_level'] ?? '';
    final phone = _profile?['phone'] ?? '';
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final tradeType = _profile?['trade_type'] ?? 'Welder';
    final yearsInField = _profile?['years_in_field'] ?? 0;

    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
      // Header
      Container(width: double.infinity, decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1e2d45))),
        child: Column(children: [
          Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 28), decoration: const BoxDecoration(color: Color(0xFF1a2235), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            child: Column(children: [
              Stack(children: [
                Container(width: 100, height: 100, decoration: BoxDecoration(color: const Color(0xFF1E3A5F), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFF6B35), width: 3)), child: const Icon(Icons.person, color: Color(0xFFFF6B35), size: 52)),
                Positioned(bottom: 0, right: 0, child: Container(width: 32, height: 32, decoration: const BoxDecoration(color: Color(0xFFFF6B35), shape: BoxShape.circle),
                  child: IconButton(icon: const Icon(Icons.camera_alt, color: Colors.white, size: 16), padding: EdgeInsets.zero, onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo coming soon!'), backgroundColor: Color(0xFFFF6B35))); }))),
              ]),
              const SizedBox(height: 14), Text(name, style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: _role == 'journeyman' ? const Color(0xFF1E3A5F) : const Color(0xFFFF6B35).withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                child: Text((_role ?? 'helper').toUpperCase(), style: TextStyle(color: _role == 'journeyman' ? const Color(0xFF7eb3ff) : const Color(0xFFFF6B35), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2))),
            ])),
          Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            if (location.isNotEmpty) _infoRow(Icons.location_on, location),
            _infoRow(Icons.build, tradeType),
            if (experience.isNotEmpty) _infoRow(Icons.work, CrewConstants.expToLabel(experience)),
            if (yearsInField > 0) _infoRow(Icons.calendar_today, '$yearsInField years in the field'),
            if (phone.isNotEmpty) _infoRow(Icons.phone, phone),
            _infoRow(Icons.email, email),
            if (bio.isNotEmpty) ...[const SizedBox(height: 8), Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF0A0E1A), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF1e2d45))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('ABOUT ME', style: TextStyle(color: Color(0xFF8896b0), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2)), const SizedBox(height: 6), Text(bio, style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 14, height: 1.5))]))],
          ])),
        ])),

      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _startEditing, icon: const Icon(Icons.edit, size: 18), label: const Text('EDIT PROFILE'))),
      const SizedBox(height: 16),

      // Stats
      Container(width: double.infinity, decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1e2d45))), padding: const EdgeInsets.all(16),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _statItem('${_certifications.length}', 'Certs'), Container(width: 1, height: 40, color: const Color(0xFF1e2d45)),
          _statItem(yearsInField > 0 ? '$yearsInField' : '—', 'Years'), Container(width: 1, height: 40, color: const Color(0xFF1e2d45)),
          _statItem('${_crewHistory.length}', 'Crew'),
        ])),

      const SizedBox(height: 16),

      // Crew History
      _sectionCard(_role == 'journeyman' ? 'CREW I\'VE HIRED' : 'PEOPLE I\'VE WORKED FOR', Icons.group,
        _crewHistory.isEmpty ? [const Text('No crew history yet.', style: TextStyle(color: Color(0xFF8896b0), fontSize: 13))]
        : _crewHistory.map((p) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF0A0E1A), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF1e2d45))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFF1E3A5F), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFF6B35), width: 1.5)), child: const Icon(Icons.person, color: Color(0xFFFF6B35), size: 18)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p['other_name'], style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 14, fontWeight: FontWeight.w600)),
                Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: p['other_role'] == 'journeyman' ? const Color(0xFF1E3A5F) : const Color(0xFFFF6B35).withOpacity(0.2), borderRadius: BorderRadius.circular(3)),
                  child: Text((p['other_role'] ?? '').toString().toUpperCase(), style: TextStyle(color: p['other_role'] == 'journeyman' ? const Color(0xFF7eb3ff) : const Color(0xFFFF6B35), fontSize: 9, fontWeight: FontWeight.w700)))]),
              ])),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => _showEndorsementDialog(p), icon: const Icon(Icons.thumb_up, size: 14), label: const Text('ENDORSE', style: TextStyle(fontSize: 11)), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF22c55e), side: const BorderSide(color: Color(0xFF22c55e)), minimumSize: const Size(0, 34)))),
              if (_role == 'journeyman') ...[const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(onPressed: () { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Job offer sent to ${p['other_name']}!'), backgroundColor: const Color(0xFFFF6B35))); }, icon: const Icon(Icons.work, size: 14), label: const Text('OFFER WORK', style: TextStyle(fontSize: 11)), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF6B35), side: const BorderSide(color: Color(0xFFFF6B35)), minimumSize: const Size(0, 34))))],
            ]),
          ])))).toList()),

      const SizedBox(height: 12),

      // Certifications (real data)
      _sectionCard('MY CERTIFICATIONS', Icons.verified, [
        ..._certifications.map((c) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Container(
          width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF0A0E1A), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF1e2d45))),
          child: Row(children: [
            Icon(c['status'] == 'verified' ? Icons.check_circle : Icons.pending, color: c['status'] == 'verified' ? const Color(0xFF22c55e) : const Color(0xFFfbbf24), size: 18),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c['name'] ?? '', style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 13, fontWeight: FontWeight.w600)),
              if (c['expiry_date'] != null) Text('Expires: ${c['expiry_date']}', style: const TextStyle(color: Color(0xFF8896b0), fontSize: 10)),
            ])),
            if (c['photo_url'] != null) IconButton(icon: const Icon(Icons.visibility, color: Color(0xFF7eb3ff), size: 18), onPressed: () => _viewCertPhoto(c['photo_url']), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 30, minHeight: 30))
            else IconButton(icon: const Icon(Icons.camera_alt, color: Color(0xFFFF6B35), size: 18), onPressed: () => _uploadCertPhoto(c['id']), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 30, minHeight: 30)),
            IconButton(icon: const Icon(Icons.delete_outline, color: Color(0xFFef4444), size: 18), onPressed: () => _deleteCert(c['id']), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 30, minHeight: 30)),
          ]),
        ))),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: _showAddCertDialog, icon: const Icon(Icons.add, size: 16), label: const Text('ADD CERTIFICATION', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF6B35), side: const BorderSide(color: Color(0xFFFF6B35)), minimumSize: const Size(double.infinity, 40))),
      ]),

      const SizedBox(height: 32),
    ]));
  }

  Widget _buildEditMode() {
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
      Center(child: Stack(children: [
        Container(width: 90, height: 90, decoration: BoxDecoration(color: const Color(0xFF1E3A5F), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFF6B35), width: 3)), child: const Icon(Icons.person, color: Color(0xFFFF6B35), size: 48)),
        Positioned(bottom: 0, right: 0, child: Container(width: 30, height: 30, decoration: const BoxDecoration(color: Color(0xFFFF6B35), shape: BoxShape.circle), child: const Icon(Icons.camera_alt, color: Colors.white, size: 14))),
      ])),
      const SizedBox(height: 24),
      _buildField('Full Name', _nameController),
      _buildField('Phone', _phoneController, type: TextInputType.phone),
      _buildField('Location (City, Province)', _locationController),
      _buildField('Years in the Field', _yearsController, type: TextInputType.number),
      const SizedBox(height: 16),
      const Align(alignment: Alignment.centerLeft, child: Text('TRADE TYPE', style: TextStyle(color: Color(0xFF8896b0), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2))),
      const SizedBox(height: 8),
      Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: const Color(0xFF0A0E1A), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFF1e2d45))),
        child: DropdownButtonHideUnderline(child: DropdownButton<String>(
          value: CrewConstants.tradeTypes.contains(_selectedTradeType) ? _selectedTradeType : CrewConstants.tradeTypes[0],
          dropdownColor: const Color(0xFF111827), style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 15), isExpanded: true,
          items: CrewConstants.tradeTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (v) => setState(() => _selectedTradeType = v ?? 'Welder'),
        ))),
      const SizedBox(height: 16),
      const Align(alignment: Alignment.centerLeft, child: Text('EXPERIENCE LEVEL', style: TextStyle(color: Color(0xFF8896b0), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2))),
      const SizedBox(height: 8),
      Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: const Color(0xFF0A0E1A), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFF1e2d45))),
        child: DropdownButtonHideUnderline(child: DropdownButton<String>(
          value: _selectedExperience, dropdownColor: const Color(0xFF111827), style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 15), isExpanded: true,
          items: CrewConstants.experienceLevels.map((e) => DropdownMenuItem(value: e['value'], child: Text(e['label']!))).toList(),
          onChanged: (v) => setState(() => _selectedExperience = v ?? 'apprentice_1st'),
        ))),
      const SizedBox(height: 16),
      _buildField('Bio (Tell people about yourself)', _bioController, maxLines: 4),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saveProfile, child: const Text('SAVE PROFILE'))),
      const SizedBox(height: 32),
    ]));
  }

  Widget _buildField(String label, TextEditingController c, {TextInputType type = TextInputType.text, int maxLines = 1}) {
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: TextField(controller: c, keyboardType: type, maxLines: maxLines, style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 15), decoration: InputDecoration(labelText: label)));
  }

  Widget _infoRow(IconData icon, String text) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Icon(icon, color: const Color(0xFFFF6B35), size: 18), const SizedBox(width: 10), Expanded(child: Text(text, style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 14)))]));
  Widget _statItem(String value, String label) => Column(children: [Text(value, style: const TextStyle(color: Color(0xFFFF6B35), fontSize: 20, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(label, style: const TextStyle(color: Color(0xFF8896b0), fontSize: 10, fontWeight: FontWeight.w600))]);

  Widget _sectionCard(String title, IconData icon, List<Widget> children) {
    return Container(width: double.infinity, decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1e2d45))), padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: const Color(0xFFFF6B35), size: 18), const SizedBox(width: 8), Text(title, style: const TextStyle(color: Color(0xFF8896b0), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2))]), const SizedBox(height: 10), ...children]));
  }
}
