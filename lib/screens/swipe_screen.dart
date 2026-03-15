import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:geolocator/geolocator.dart';
import '../crew_constants.dart';

class SwipeScreen extends StatefulWidget {
  final String mode;
  const SwipeScreen({super.key, this.mode = 'people'});
  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen> {
  final AppinioSwiperController _swiperController = AppinioSwiperController();
  List<Map<String, dynamic>> _cards = [];
  bool _loading = true;
  String? _userRole;
  String? _error;
  Set<String> _likedYouIds = {};

  // Location
  double? _myLat;
  double? _myLng;
  double _radiusKm = 200;

  // Filters
  String _filterExperience = 'All';
  String _filterTradeType = 'All';

  @override
  void initState() { super.initState(); _initLocation(); }

  Future<void> _initLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        // Default to Calgary
        _myLat = 51.0447; _myLng = -114.0719;
      } else {
        final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low));
        _myLat = pos.latitude; _myLng = pos.longitude;
      }
    } catch (e) {
      _myLat = 51.0447; _myLng = -114.0719;
    }
    _loadData();
  }

  double _distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const p = 0.017453292519943295;
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 + cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lng2 - lng1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) { setState(() { _loading = false; _error = 'Not logged in'; }); return; }
      final userRes = await Supabase.instance.client.from('users').select('role').eq('id', userId).maybeSingle();
      _userRole = userRes?['role'] ?? 'helper';
      await _loadLikedYou(userId);
      if (widget.mode == 'jobs') { await _loadJobs(userId); } else { await _loadPeople(userId); }
    } catch (e) { setState(() { _loading = false; _error = 'Failed to load. Tap refresh.'; }); }
  }

  Future<void> _loadLikedYou(String userId) async {
    try {
      final res = await Supabase.instance.client.from('swipes').select('swiper_id').eq('swiped_id', userId).eq('direction', 'like');
      _likedYouIds = (res as List).map((s) => s['swiper_id'].toString()).toSet();
    } catch (e) { _likedYouIds = {}; }
  }

  Future<void> _loadPeople(String userId) async {
    final swipedRes = await Supabase.instance.client.from('swipes').select('swiped_id').eq('swiper_id', userId);
    final swipedIds = (swipedRes as List).map((s) => s['swiped_id']).toList();
    final oppositeRole = _userRole == 'journeyman' ? 'helper' : 'journeyman';
    final profilesRes = await Supabase.instance.client.from('users').select('id, email, role, profiles(full_name, bio, location_text, experience_level, profile_photo_url, trade_type, years_in_field, latitude, longitude)').eq('role', oppositeRole).neq('id', userId).limit(50);
    var filtered = (profilesRes as List).where((p) => !swipedIds.contains(p['id'])).toList().cast<Map<String, dynamic>>();

    // Radius filter
    if (_myLat != null && _myLng != null) {
      filtered = filtered.where((p) {
        final pr = p['profiles'] as Map<String, dynamic>?;
        final lat = pr?['latitude'] as double?;
        final lng = pr?['longitude'] as double?;
        if (lat == null || lng == null) return true;
        return _distanceKm(_myLat!, _myLng!, lat, lng) <= _radiusKm;
      }).toList();
    }
    if (_filterExperience != 'All') { filtered = filtered.where((p) { final exp = (p['profiles'] as Map<String, dynamic>?)?['experience_level'] ?? ''; return exp == _filterExperience; }).toList(); }
    if (_filterTradeType != 'All') { filtered = filtered.where((p) { final trade = (p['profiles'] as Map<String, dynamic>?)?['trade_type'] ?? ''; return trade.toLowerCase() == _filterTradeType.toLowerCase(); }).toList(); }
    setState(() { _cards = filtered; _loading = false; });
  }

  Future<void> _loadJobs(String userId) async {
    final swipedRes = await Supabase.instance.client.from('job_swipes').select('job_id').eq('user_id', userId);
    final swipedJobIds = (swipedRes as List).map((s) => s['job_id']).toList();
    final jobsRes = await Supabase.instance.client.from('jobs').select('id, title, description, location_text, hourly_rate, experience_required, duration_days, start_date, end_date, journeyman_id, latitude, longitude, users!jobs_journeyman_id_fkey(profiles(full_name))').eq('is_active', true).limit(50);
    var filtered = (jobsRes as List).where((j) => !swipedJobIds.contains(j['id'])).toList().cast<Map<String, dynamic>>();

    if (_myLat != null && _myLng != null) {
      filtered = filtered.where((j) {
        final lat = j['latitude'] as double?;
        final lng = j['longitude'] as double?;
        if (lat == null || lng == null) return true;
        return _distanceKm(_myLat!, _myLng!, lat, lng) <= _radiusKm;
      }).toList();
    }
    if (_filterExperience != 'All') { filtered = filtered.where((j) { final exp = j['experience_required'] ?? 'any'; return exp == _filterExperience || exp == 'any'; }).toList(); }
    if (_filterTradeType != 'All') { filtered = filtered.where((j) { final desc = (j['title'] ?? '').toString().toLowerCase() + (j['description'] ?? '').toString().toLowerCase(); return desc.contains(_filterTradeType.toLowerCase()); }).toList(); }
    setState(() { _cards = filtered; _loading = false; });
  }

  Future<void> _recordSwipe(String targetId, bool liked) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      if (widget.mode == 'jobs') {
        await Supabase.instance.client.from('job_swipes').insert({'user_id': userId, 'job_id': targetId, 'liked': liked});
      } else {
        await Supabase.instance.client.from('swipes').insert({'swiper_id': userId, 'swiped_id': targetId, 'direction': liked ? 'like' : 'pass'});
        if (liked) await _checkForMatch(userId, targetId);
      }
    } catch (e) { debugPrint('Swipe error: $e'); }
  }

  Future<void> _checkForMatch(String userId, String swipedId) async {
    try {
      final mutual = await Supabase.instance.client.from('swipes').select('id').eq('swiper_id', swipedId).eq('swiped_id', userId).eq('direction', 'like').maybeSingle();
      if (mutual != null) {
        String jId = _userRole == 'journeyman' ? userId : swipedId;
        String hId = _userRole == 'journeyman' ? swipedId : userId;
        await Supabase.instance.client.from('matches').insert({'journeyman_id': jId, 'helper_id': hId});
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎉 It\'s a match! Check your matches tab.', style: TextStyle(fontWeight: FontWeight.w700)), backgroundColor: Color(0xFFFF6B35), duration: Duration(seconds: 3))); }
      }
    } catch (e) {}
  }

  void _showFilters() {
    double tempRadius = _radiusKm;
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF111827), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.tune, color: Color(0xFFFF6B35), size: 20), const SizedBox(width: 8), const Text('FILTERS', style: TextStyle(color: Color(0xFFF0F4FF), fontSize: 18, fontWeight: FontWeight.w700)), const Spacer(), TextButton(onPressed: () { setS(() { tempRadius = 200; _filterExperience = 'All'; _filterTradeType = 'All'; }); }, child: const Text('Reset', style: TextStyle(color: Color(0xFF8896b0))))]),
        const SizedBox(height: 16),

        // Radius slider
        Text('DISTANCE: ${tempRadius.round()} KM', style: const TextStyle(color: Color(0xFF8896b0), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2)),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderThemeData(activeTrackColor: const Color(0xFFFF6B35), inactiveTrackColor: const Color(0xFF1e2d45), thumbColor: const Color(0xFFFF6B35), overlayColor: const Color(0xFFFF6B35).withOpacity(0.2)),
          child: Slider(min: 10, max: 500, divisions: 49, value: tempRadius, label: '${tempRadius.round()} km',
            onChanged: (v) => setS(() => tempRadius = v)),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('10 km', style: TextStyle(color: Color(0xFF8896b0), fontSize: 10)), const Text('500 km', style: TextStyle(color: Color(0xFF8896b0), fontSize: 10))]),

        const SizedBox(height: 16),
        const Text('EXPERIENCE', style: TextStyle(color: Color(0xFF8896b0), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2)),
        const SizedBox(height: 8),
        _dd(['All', '1st Year', '2nd Year', '3rd Year', '4th Year', 'Journeyman'], CrewConstants.expToLabel(_filterExperience) == 'All' ? 'All' : CrewConstants.expToLabel(_filterExperience), (v) { setS(() => _filterExperience = CrewConstants.labelToExp(v!)); }),

        const SizedBox(height: 16),
        const Text('TRADE TYPE', style: TextStyle(color: Color(0xFF8896b0), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2)),
        const SizedBox(height: 8),
        _dd(CrewConstants.tradeFilterLabels, _filterTradeType, (v) { setS(() => _filterTradeType = v!); }),

        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () { _radiusKm = tempRadius; Navigator.pop(ctx); _loadData(); }, child: const Text('APPLY FILTERS'))),
        const SizedBox(height: 8),
      ]))));
  }

  Widget _dd(List<String> items, String val, ValueChanged<String?> cb) {
    return Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: const Color(0xFF0A0E1A), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFF1e2d45))),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: items.contains(val) ? val : items[0], dropdownColor: const Color(0xFF111827), style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 15), isExpanded: true, items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(), onChanged: cb)));
  }

  @override
  void dispose() { _swiperController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isJobs = widget.mode == 'jobs';
    final hasF = _filterExperience != 'All' || _filterTradeType != 'All' || _radiusKm < 200;
    return Scaffold(
      appBar: AppBar(title: Text(isJobs ? 'JOBS' : 'CREW'), actions: [
        if (hasF) Container(margin: const EdgeInsets.only(right: 4), width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFF6B35), shape: BoxShape.circle)),
        IconButton(icon: const Icon(Icons.tune, color: Color(0xFFFF6B35)), onPressed: _showFilters),
        IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF8896b0)), onPressed: _loadData),
      ]),
      body: _loading ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
          : _error != null ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('⚠️', style: TextStyle(fontSize: 48)), const SizedBox(height: 16), Text(_error!, style: const TextStyle(color: Color(0xFF8896b0))), const SizedBox(height: 24), ElevatedButton(onPressed: _loadData, child: const Text('TRY AGAIN'))]))
          : _cards.isEmpty ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(isJobs ? '📋' : '🔧', style: const TextStyle(fontSize: 48)), const SizedBox(height: 16), Text(isJobs ? 'No jobs in range' : 'No people in range', style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 20, fontWeight: FontWeight.w700)), const SizedBox(height: 8), Text('Try increasing your distance filter', style: const TextStyle(color: Color(0xFF8896b0))), const SizedBox(height: 24), ElevatedButton(onPressed: _showFilters, child: const Text('ADJUST FILTERS'))]))
          : _buildSwiper(isJobs),
    );
  }

  Widget _buildSwiper(bool isJobs) {
    return Column(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), child: Row(children: [Text('${_cards.length} ${isJobs ? 'jobs' : 'people'} within ${_radiusKm.round()}km', style: const TextStyle(color: Color(0xFF8896b0), fontSize: 12)), const Spacer(), const Text('← PASS     LIKE →', style: TextStyle(color: Color(0xFF8896b0), fontSize: 10, letterSpacing: 1))])),
      Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: AppinioSwiper(controller: _swiperController, cardCount: _cards.length, onSwipeEnd: (prev, tgt, act) { _recordSwipe(_cards[prev]['id'].toString(), act.direction == AxisDirection.right); }, cardBuilder: (ctx, i) => isJobs ? _buildJobCard(_cards[i]) : _buildPersonCard(_cards[i])))),
      Padding(padding: const EdgeInsets.only(bottom: 32, left: 48, right: 48), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        GestureDetector(onTap: () => _swiperController.swipeLeft(), child: Container(width: 64, height: 64, decoration: BoxDecoration(color: const Color(0xFF111827), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFef4444), width: 2)), child: const Icon(Icons.close, color: Color(0xFFef4444), size: 32))),
        GestureDetector(onTap: () => _swiperController.swipeRight(), child: Container(width: 72, height: 72, decoration: BoxDecoration(color: const Color(0xFFFF6B35), shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFFFF6B35).withOpacity(0.4), blurRadius: 16, spreadRadius: 2)]), child: const Icon(Icons.check, color: Colors.white, size: 36))),
      ])),
    ]);
  }

  Widget _buildPersonCard(Map<String, dynamic> user) {
    final p = user['profiles'] as Map<String, dynamic>?;
    final name = p?['full_name'] ?? user['email'] ?? 'Unknown';
    final bio = p?['bio'] ?? 'No bio yet';
    final loc = p?['location_text'] ?? 'Alberta';
    final exp = p?['experience_level'] ?? '';
    final role = user['role'] ?? '';
    final trade = p?['trade_type'] ?? '';
    final yrs = p?['years_in_field'] ?? 0;
    final liked = _likedYouIds.contains(user['id'].toString());

    // Distance
    String distLabel = '';
    if (_myLat != null && _myLng != null && p?['latitude'] != null && p?['longitude'] != null) {
      final d = _distanceKm(_myLat!, _myLng!, (p!['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble());
      distLabel = '${d.round()} km away';
    }

    return Container(
      decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(16), border: Border.all(color: liked ? const Color(0xFF22c55e) : const Color(0xFF1e2d45), width: liked ? 2 : 1)),
      child: Stack(children: [
        Column(children: [
          Expanded(flex: 3, child: Container(decoration: const BoxDecoration(color: Color(0xFF1a2235), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 100, height: 100, decoration: BoxDecoration(color: const Color(0xFF1E3A5F), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFF6B35), width: 2)), child: const Icon(Icons.person, color: Color(0xFFFF6B35), size: 52)),
              const SizedBox(height: 16), Text(name, style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 24, fontWeight: FontWeight.w700)), const SizedBox(height: 4),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: role == 'journeyman' ? const Color(0xFF1E3A5F) : const Color(0xFFFF6B35).withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                child: Text(role.toUpperCase(), style: TextStyle(color: role == 'journeyman' ? const Color(0xFF7eb3ff) : const Color(0xFFFF6B35), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2))),
            ])))),
          Expanded(flex: 2, child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Icon(Icons.location_on, color: Color(0xFF8896b0), size: 16), const SizedBox(width: 4), Flexible(child: Text(loc, style: const TextStyle(color: Color(0xFF8896b0), fontSize: 13), overflow: TextOverflow.ellipsis)),
              if (distLabel.isNotEmpty) ...[const SizedBox(width: 6), Text('• $distLabel', style: const TextStyle(color: Color(0xFFFF6B35), fontSize: 11, fontWeight: FontWeight.w600))]]),
            const SizedBox(height: 6),
            Row(children: [
              if (trade.isNotEmpty) ...[const Icon(Icons.build, color: Color(0xFF8896b0), size: 14), const SizedBox(width: 4), Text(trade, style: const TextStyle(color: Color(0xFF8896b0), fontSize: 12)), const SizedBox(width: 10)],
              const Icon(Icons.work, color: Color(0xFF8896b0), size: 14), const SizedBox(width: 4), Text(CrewConstants.expToLabel(exp), style: const TextStyle(color: Color(0xFF8896b0), fontSize: 12)),
              if (yrs > 0) ...[const SizedBox(width: 10), Text('$yrs yrs', style: const TextStyle(color: Color(0xFF8896b0), fontSize: 12))],
            ]),
            const SizedBox(height: 10), Expanded(child: Text(bio, style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 14, height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis)),
          ]))),
        ]),
        if (liked) Positioned(top: 12, right: 12, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: const Color(0xFF22c55e), borderRadius: BorderRadius.circular(6)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.favorite, color: Colors.white, size: 14), SizedBox(width: 4), Text('INTERESTED IN YOU', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1))]))),
      ]),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final title = job['title'] ?? 'Untitled';
    final desc = job['description'] ?? '';
    final loc = job['location_text'] ?? 'Alberta';
    final rate = job['hourly_rate'];
    final dur = job['duration_days'];
    final exp = job['experience_required'] ?? 'any';
    final poster = job['users']?['profiles']?['full_name'] ?? 'Unknown';
    final sd = job['start_date'];
    String el = exp; switch (exp) { case 'any': el = 'Any Level'; break; case 'apprentice': el = 'Apprentice'; break; case 'journeyman': el = 'Journeyman'; break; }
    bool urgent = false; if (sd != null) { try { urgent = DateTime.parse(sd).difference(DateTime.now()).inDays <= 7; } catch (e) {} }
    final hp = rate != null && rate >= 45;

    String distLabel = '';
    if (_myLat != null && _myLng != null && job['latitude'] != null && job['longitude'] != null) {
      final d = _distanceKm(_myLat!, _myLng!, (job['latitude'] as num).toDouble(), (job['longitude'] as num).toDouble());
      distLabel = '${d.round()} km';
    }

    return Container(
      decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(16), border: Border.all(color: urgent ? const Color(0xFFef4444) : const Color(0xFF1e2d45), width: urgent ? 2 : 1)),
      child: Stack(children: [
        Column(children: [
          Expanded(flex: 3, child: Container(decoration: const BoxDecoration(color: Color(0xFF1a2235), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 100, height: 100, decoration: BoxDecoration(color: const Color(0xFF1E3A5F), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFFF6B35), width: 2)), child: const Icon(Icons.work, color: Color(0xFFFF6B35), size: 52)),
              const SizedBox(height: 16), Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text(title, style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 22, fontWeight: FontWeight.w700), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis)),
              const SizedBox(height: 6), Text('Posted by $poster', style: const TextStyle(color: Color(0xFF8896b0), fontSize: 13)),
            ])))),
          Expanded(flex: 2, child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              _infoChip(Icons.location_on, distLabel.isNotEmpty ? '$loc • $distLabel' : loc),
              if (rate != null) _infoChip(Icons.attach_money, '\$$rate/hr', color: const Color(0xFF22c55e)),
              if (dur != null) _infoChip(Icons.schedule, '$dur days'),
              _infoChip(Icons.star, el, color: const Color(0xFF7eb3ff)),
            ]),
            const SizedBox(height: 12), Expanded(child: Text(desc, style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 14, height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis)),
          ]))),
        ]),
        Positioned(top: 12, right: 12, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (urgent) Container(margin: const EdgeInsets.only(bottom: 4), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFef4444), borderRadius: BorderRadius.circular(6)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.access_time, color: Colors.white, size: 14), SizedBox(width: 4), Text('URGENT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1))])),
          if (hp) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: const Color(0xFF22c55e), borderRadius: BorderRadius.circular(6)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.trending_up, color: Colors.white, size: 14), SizedBox(width: 4), Text('HIGH PAY', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1))])),
        ])),
      ]),
    );
  }

  Widget _infoChip(IconData icon, String label, {Color? color}) {
    final c = color ?? const Color(0xFF8896b0);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: c, size: 14), const SizedBox(width: 4), Flexible(child: Text(label, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis))]));
  }
}
