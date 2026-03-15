import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../crew_constants.dart';
import 'job_detail_screen.dart';

class JobPostScreen extends StatefulWidget {
  const JobPostScreen({super.key});
  @override
  State<JobPostScreen> createState() => _JobPostScreenState();
}

class _JobPostScreenState extends State<JobPostScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _myJobs = [];
  List<Map<String, dynamic>> _allJobs = [];
  bool _loadingMy = true;
  bool _loadingAll = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  Future<void> _loadAll() async {
    await Future.wait([_loadMyJobs(), _loadDiscoverJobs()]);
  }

  Future<void> _loadMyJobs() async {
    setState(() => _loadingMy = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) { setState(() => _loadingMy = false); return; }
      final res = await Supabase.instance.client.from('jobs').select().eq('journeyman_id', userId).order('created_at', ascending: false);
      setState(() { _myJobs = (res as List).cast<Map<String, dynamic>>(); _loadingMy = false; });
    } catch (e) { setState(() => _loadingMy = false); }
  }

  Future<void> _loadDiscoverJobs() async {
    setState(() => _loadingAll = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final res = await Supabase.instance.client.from('jobs').select('id, title, description, location_text, hourly_rate, experience_required, duration_days, start_date, journeyman_id, trade_type').eq('is_active', true).neq('journeyman_id', userId ?? '').order('created_at', ascending: false).limit(50);
      setState(() { _allJobs = (res as List).cast<Map<String, dynamic>>(); _loadingAll = false; });
    } catch (e) { setState(() => _loadingAll = false); }
  }

  Future<void> _deleteJob(String jobId) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF111827),
      title: const Text('Delete Job', style: TextStyle(color: Color(0xFFF0F4FF))),
      content: const Text('Are you sure?', style: TextStyle(color: Color(0xFF8896b0))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL', style: TextStyle(color: Color(0xFF8896b0)))), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('DELETE', style: TextStyle(color: Color(0xFFef4444))))],
    ));
    if (confirm != true) return;
    try {
      await Supabase.instance.client.from('jobs').delete().eq('id', jobId);
      _loadMyJobs();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job deleted'), backgroundColor: Color(0xFF22c55e)));
    } catch (e) {}
  }

  void _openJobForm({Map<String, dynamic>? existingJob}) {
    Navigator.push(context, MaterialPageRoute(builder: (ctx) => _JobFormPage(existingJob: existingJob, onSaved: () => _loadAll())));
  }

  void _openJobDetail(Map<String, dynamic> job) {
    Navigator.push(context, MaterialPageRoute(builder: (ctx) => JobDetailScreen(job: job)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JOBS'),
        bottom: TabBar(controller: _tabController, indicatorColor: const Color(0xFFFF6B35), labelColor: const Color(0xFFFF6B35), unselectedLabelColor: const Color(0xFF8896b0),
          tabs: const [Tab(text: 'DISCOVER'), Tab(text: 'MY POSTS')]),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF8896b0)), onPressed: _loadAll)],
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _openJobForm(), backgroundColor: const Color(0xFFFF6B35), child: const Icon(Icons.add, color: Colors.white)),
      body: TabBarView(controller: _tabController, children: [_buildDiscoverTab(), _buildMyPostsTab()]),
    );
  }

  Widget _buildDiscoverTab() {
    if (_loadingAll) return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)));
    if (_allJobs.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('📋', style: TextStyle(fontSize: 48)), const SizedBox(height: 16),
      const Text('No other jobs posted yet', style: TextStyle(color: Color(0xFFF0F4FF), fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8), const Text('Check back later', style: TextStyle(color: Color(0xFF8896b0))),
    ]));

    return ListView.separated(padding: const EdgeInsets.all(16), itemCount: _allJobs.length, separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final job = _allJobs[index];
        final title = job['title'] ?? 'Untitled';
        final location = job['location_text'] ?? '';
        final rate = job['hourly_rate'];
        final duration = job['duration_days'];
        final tradeType = job['trade_type'] ?? '';
        final exp = job['experience_required'] ?? 'any';

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
                if (location.isNotEmpty) _chip('📍 $location'),
                if (rate != null) _chipColor('\$$rate/hr', const Color(0xFF22c55e)),
                if (duration != null) _chip('$duration days'),
                if (tradeType.isNotEmpty) _chip(tradeType),
                _chipColor(CrewConstants.expToLabel(exp), const Color(0xFF7eb3ff)),
              ]),
              const SizedBox(height: 8),
              Text(job['description'] ?? '', style: const TextStyle(color: Color(0xFF8896b0), fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildMyPostsTab() {
    if (_loadingMy) return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)));
    if (_myJobs.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('📋', style: TextStyle(fontSize: 48)), const SizedBox(height: 16),
      const Text('No jobs posted yet', style: TextStyle(color: Color(0xFFF0F4FF), fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8), const Text('Tap + to post your first job', style: TextStyle(color: Color(0xFF8896b0))),
    ]));

    return ListView.separated(padding: const EdgeInsets.all(16), itemCount: _myJobs.length, separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final job = _myJobs[index];
        final title = job['title'] ?? 'Untitled';
        final location = job['location_text'] ?? '';
        final rate = job['hourly_rate'];
        final duration = job['duration_days'];
        final isActive = job['is_active'] ?? false;
        final tradeType = job['trade_type'] ?? '';

        return Container(
          decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1e2d45))),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFF1E3A5F), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFF6B35), width: 1.5)), child: const Icon(Icons.work, color: Color(0xFFFF6B35), size: 22)),
            title: Row(children: [
              Expanded(child: Text(title, style: const TextStyle(color: Color(0xFFF0F4FF), fontWeight: FontWeight.w600, fontSize: 15))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: isActive ? const Color(0xFF22c55e).withOpacity(0.15) : const Color(0xFFef4444).withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                child: Text(isActive ? 'ACTIVE' : 'CLOSED', style: TextStyle(color: isActive ? const Color(0xFF22c55e) : const Color(0xFFef4444), fontSize: 10, fontWeight: FontWeight.w700))),
            ]),
            subtitle: Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(spacing: 6, runSpacing: 4, children: [
              if (location.isNotEmpty) _chip('📍 $location'),
              if (rate != null) _chip('\$$rate/hr'),
              if (duration != null) _chip('$duration days'),
              if (tradeType.isNotEmpty) _chip(tradeType),
            ])),
            trailing: PopupMenuButton<String>(icon: const Icon(Icons.more_vert, color: Color(0xFF8896b0)), color: const Color(0xFF111827),
              onSelected: (v) { if (v == 'edit') _openJobForm(existingJob: job); else if (v == 'delete') _deleteJob(job['id'].toString()); },
              itemBuilder: (ctx) => [const PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: Color(0xFFF0F4FF)))), const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Color(0xFFef4444))))]),
          ),
        );
      },
    );
  }

  Widget _chip(String label) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF1a2235), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: const TextStyle(color: Color(0xFF8896b0), fontSize: 11, fontWeight: FontWeight.w600)));
  }

  Widget _chipColor(String label, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)));
  }
}

class _JobFormPage extends StatefulWidget {
  final Map<String, dynamic>? existingJob;
  final VoidCallback onSaved;
  const _JobFormPage({this.existingJob, required this.onSaved});
  @override
  State<_JobFormPage> createState() => _JobFormPageState();
}

class _JobFormPageState extends State<_JobFormPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _rateController = TextEditingController();
  final _durationController = TextEditingController();
  String _experienceRequired = 'any';
  String _tradeType = 'Welder';
  bool _isActive = true;
  bool _saving = false;
  bool get _isEditing => widget.existingJob != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final job = widget.existingJob!;
      _titleController.text = job['title'] ?? '';
      _descriptionController.text = job['description'] ?? '';
      _locationController.text = job['location_text'] ?? '';
      _rateController.text = (job['hourly_rate'] ?? '').toString();
      _durationController.text = (job['duration_days'] ?? '').toString();
      _experienceRequired = job['experience_required'] ?? 'any';
      if (_experienceRequired == 'master') _experienceRequired = 'journeyman';
      _tradeType = job['trade_type'] ?? 'Welder';
      _isActive = job['is_active'] ?? true;
    }
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a job title'), backgroundColor: Color(0xFFef4444))); return; }
    setState(() => _saving = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final data = {
        'journeyman_id': userId, 'title': _titleController.text.trim(), 'description': _descriptionController.text.trim(),
        'location_text': _locationController.text.trim(), 'hourly_rate': double.tryParse(_rateController.text.trim()),
        'duration_days': int.tryParse(_durationController.text.trim()), 'experience_required': _experienceRequired,
        'trade_type': _tradeType, 'is_active': _isActive,
      };
      if (_isEditing) { await Supabase.instance.client.from('jobs').update(data).eq('id', widget.existingJob!['id']); }
      else { await Supabase.instance.client.from('jobs').insert(data); }
      widget.onSaved();
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEditing ? 'Job updated!' : 'Job posted!'), backgroundColor: const Color(0xFF22c55e))); Navigator.pop(context); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error saving job'), backgroundColor: Color(0xFFef4444))); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  void dispose() { _titleController.dispose(); _descriptionController.dispose(); _locationController.dispose(); _rateController.dispose(); _durationController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'EDIT JOB' : 'POST JOB')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('JOB TITLE'), const SizedBox(height: 8),
        TextField(controller: _titleController, style: const TextStyle(color: Color(0xFFF0F4FF)), decoration: const InputDecoration(hintText: 'e.g. Welder Helper Needed')),
        const SizedBox(height: 20),
        _label('DESCRIPTION'), const SizedBox(height: 8),
        TextField(controller: _descriptionController, style: const TextStyle(color: Color(0xFFF0F4FF)), maxLines: 4, decoration: const InputDecoration(hintText: 'Describe the job, requirements, etc.')),
        const SizedBox(height: 20),
        _label('LOCATION'), const SizedBox(height: 8),
        TextField(controller: _locationController, style: const TextStyle(color: Color(0xFFF0F4FF)), decoration: const InputDecoration(hintText: 'e.g. Edmonton, AB')),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('HOURLY RATE (\$)'), const SizedBox(height: 8), TextField(controller: _rateController, keyboardType: TextInputType.number, style: const TextStyle(color: Color(0xFFF0F4FF)), decoration: const InputDecoration(hintText: '45'))])),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('DURATION (DAYS)'), const SizedBox(height: 8), TextField(controller: _durationController, keyboardType: TextInputType.number, style: const TextStyle(color: Color(0xFFF0F4FF)), decoration: const InputDecoration(hintText: '14'))])),
        ]),
        const SizedBox(height: 20),
        _label('TRADE TYPE'), const SizedBox(height: 8),
        Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: const Color(0xFF0A0E1A), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFF1e2d45))),
          child: DropdownButtonHideUnderline(child: DropdownButton<String>(
            value: CrewConstants.tradeTypes.contains(_tradeType) ? _tradeType : CrewConstants.tradeTypes[0],
            dropdownColor: const Color(0xFF111827), style: const TextStyle(color: Color(0xFFF0F4FF)), isExpanded: true,
            items: CrewConstants.tradeTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setState(() => _tradeType = v ?? 'Welder'),
          ))),
        const SizedBox(height: 20),
        _label('EXPERIENCE REQUIRED'), const SizedBox(height: 8),
        Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: const Color(0xFF0A0E1A), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFF1e2d45))),
          child: DropdownButtonHideUnderline(child: DropdownButton<String>(
            value: _experienceRequired, dropdownColor: const Color(0xFF111827), style: const TextStyle(color: Color(0xFFF0F4FF)), isExpanded: true,
            items: [const DropdownMenuItem(value: 'any', child: Text('Any Level')), ...CrewConstants.experienceLevels.map((e) => DropdownMenuItem(value: e['value'], child: Text(e['label']!)))],
            onChanged: (v) => setState(() => _experienceRequired = v ?? 'any'),
          ))),
        if (_isEditing) ...[const SizedBox(height: 20), Row(children: [_label('ACTIVE'), const Spacer(), Switch(value: _isActive, activeColor: const Color(0xFFFF6B35), onChanged: (v) => setState(() => _isActive = v))])],
        const SizedBox(height: 32),
        ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(_isEditing ? 'UPDATE JOB' : 'POST JOB')),
        const SizedBox(height: 32),
      ])),
    );
  }

  Widget _label(String t) => Text(t, style: const TextStyle(color: Color(0xFF8896b0), fontSize: 11, letterSpacing: 2));
}
