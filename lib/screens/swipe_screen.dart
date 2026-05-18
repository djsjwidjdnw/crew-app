import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:geolocator/geolocator.dart';
import '../crew_constants.dart';
import 'view_profile_screen.dart';
import 'job_detail_screen.dart';

class SwipeScreen extends StatefulWidget {
  final String mode; // 'people' or 'jobs'
  const SwipeScreen({super.key, this.mode = 'people'});

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen> {
  final AppinioSwiperController _swiperController = AppinioSwiperController();
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _cards = [];
  Set<String> _interestedInMeIds = {}; // people who already liked current user
  bool _loading = true;
  bool _gettingLocation = false;
  String? _userId;
  String? _userRole;
  Position? _myPosition;
  double? _myLat;
  double? _myLng;

  // Filters
  double _radiusKm = 100;
  String _experienceFilter = 'All';
  String _tradeFilter = 'All';

  @override
  void initState() {
    super.initState();
    _userId = _supabase.auth.currentUser?.id;
    _initialize();
  }

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _loadCurrentUser();
    await _getLocation();
    await _loadCards();
  }

  Future<void> _loadCurrentUser() async {
    if (_userId == null) return;
    try {
      final userRes = await _supabase
          .from('users')
          .select('role')
          .eq('id', _userId!)
          .maybeSingle();
      _userRole = userRes?['role'];
      final profileRes = await _supabase
          .from('profiles')
          .select('latitude, longitude')
          .eq('user_id', _userId!)
          .maybeSingle();
      if (profileRes != null) {
        _myLat = (profileRes['latitude'] as num?)?.toDouble();
        _myLng = (profileRes['longitude'] as num?)?.toDouble();
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
    }
  }

  Future<void> _getLocation() async {
    setState(() => _gettingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _gettingLocation = false;
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _gettingLocation = false;
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _gettingLocation = false;
        return;
      }
      _myPosition = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.medium));
      _myLat = _myPosition?.latitude ?? _myLat;
      _myLng = _myPosition?.longitude ?? _myLng;

      // Optionally save back to profile
      if (_userId != null && _myLat != null && _myLng != null) {
        try {
          await _supabase
              .from('profiles')
              .update({'latitude': _myLat, 'longitude': _myLng})
              .eq('user_id', _userId!);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Location error: $e');
    }
    if (mounted) setState(() => _gettingLocation = false);
  }

  Future<void> _loadCards() async {
    setState(() => _loading = true);
    if (widget.mode == 'people') {
      await _loadPeople();
    } else {
      await _loadJobs();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadInterestedInMe() async {
    if (_userId == null) return;
    try {
      final res = await _supabase
          .from('swipes')
          .select('swiper_id')
          .eq('swiped_id', _userId!)
          .eq('direction', 'like');
      _interestedInMeIds =
          ((res as List).map((s) => s['swiper_id'] as String).toSet());
    } catch (e) {
      _interestedInMeIds = {};
    }
  }

  Future<Set<String>> _alreadySwipedIds() async {
    if (_userId == null) return {};
    try {
      final res = await _supabase
          .from('swipes')
          .select('swiped_id')
          .eq('swiper_id', _userId!);
      return (res as List).map((s) => s['swiped_id'] as String).toSet();
    } catch (e) {
      return {};
    }
  }

  Future<Set<String>> _alreadySwipedJobIds() async {
    if (_userId == null) return {};
    try {
      final res = await _supabase
          .from('job_swipes')
          .select('job_id')
          .eq('user_id', _userId!);
      return (res as List).map((s) => s['job_id'].toString()).toSet();
    } catch (e) {
      return {};
    }
  }

  Future<void> _loadPeople() async {
    if (_userId == null) {
      _cards = [];
      return;
    }
    try {
      await _loadInterestedInMe();
      final swipedIds = await _alreadySwipedIds();

      // Determine target role: helpers see journeymen, journeymen see helpers
      final targetRole = _userRole == 'journeyman' ? 'helper' : 'journeyman';

      // Pull users with profiles
      final usersRes = await _supabase
          .from('users')
          .select('id, email, role')
          .eq('role', targetRole)
          .neq('id', _userId!)
          .limit(100);

      final users = (usersRes as List).cast<Map<String, dynamic>>();
      List<Map<String, dynamic>> filtered = [];

      for (final user in users) {
        final uid = user['id'] as String;
        if (swipedIds.contains(uid)) continue;

        Map<String, dynamic>? profile;
        try {
          profile = await _supabase
              .from('profiles')
              .select(
                  'full_name, location_text, bio, experience_level, trade_type, years_in_field, phone, profile_photo_url, latitude, longitude')
              .eq('user_id', uid)
              .maybeSingle();
        } catch (_) {}

        if (profile == null) continue;

        // Apply experience filter
        if (_experienceFilter != 'All') {
          final filterValue = CrewConstants.labelToExp(_experienceFilter);
          if ((profile['experience_level'] ?? '') != filterValue) continue;
        }
        // Apply trade filter
        if (_tradeFilter != 'All') {
          if ((profile['trade_type'] ?? '') != _tradeFilter) continue;
        }

        // Apply radius filter if we have coordinates
        double? distanceKm;
        final candLat = (profile['latitude'] as num?)?.toDouble();
        final candLng = (profile['longitude'] as num?)?.toDouble();
        if (_myLat != null &&
            _myLng != null &&
            candLat != null &&
            candLng != null) {
          distanceKm = Geolocator.distanceBetween(
                  _myLat!, _myLng!, candLat, candLng) /
              1000;
          if (distanceKm > _radiusKm) continue;
        }

        filtered.add({
          'user': user,
          'profile': profile,
          'distance_km': distanceKm,
        });
      }

      // Sort: interested-in-me first, then by distance ascending (nulls last)
      filtered.sort((a, b) {
        final aInterested =
            _interestedInMeIds.contains((a['user'] as Map)['id']);
        final bInterested =
            _interestedInMeIds.contains((b['user'] as Map)['id']);
        if (aInterested != bInterested) return aInterested ? -1 : 1;
        final ad = a['distance_km'] as double?;
        final bd = b['distance_km'] as double?;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });

      _cards = filtered;
    } catch (e) {
      debugPrint('Error loading people: $e');
      _cards = [];
    }
  }

  Future<void> _loadJobs() async {
    if (_userId == null) {
      _cards = [];
      return;
    }
    try {
      final swipedJobIds = await _alreadySwipedJobIds();
      final res = await _supabase
          .from('jobs')
          .select(
              'id, title, description, location_text, hourly_rate, experience_required, duration_days, journeyman_id, trade_type, start_date, urgent, is_active, latitude, longitude, created_at')
          .eq('is_active', true)
          .neq('journeyman_id', _userId!)
          .order('created_at', ascending: false)
          .limit(100);

      final jobs = (res as List).cast<Map<String, dynamic>>();
      List<Map<String, dynamic>> filtered = [];

      for (final job in jobs) {
        if (swipedJobIds.contains(job['id'].toString())) continue;

        // Experience filter
        if (_experienceFilter != 'All') {
          final filterValue = CrewConstants.labelToExp(_experienceFilter);
          final required = job['experience_required'] ?? 'any';
          if (required != 'any' && required != filterValue) continue;
        }
        // Trade filter
        if (_tradeFilter != 'All') {
          if ((job['trade_type'] ?? '') != _tradeFilter) continue;
        }

        double? distanceKm;
        final jLat = (job['latitude'] as num?)?.toDouble();
        final jLng = (job['longitude'] as num?)?.toDouble();
        if (_myLat != null && _myLng != null && jLat != null && jLng != null) {
          distanceKm =
              Geolocator.distanceBetween(_myLat!, _myLng!, jLat, jLng) / 1000;
          if (distanceKm > _radiusKm) continue;
        }

        filtered.add({...job, 'distance_km': distanceKm});
      }

      _cards = filtered;
    } catch (e) {
      debugPrint('Error loading jobs: $e');
      _cards = [];
    }
  }

  Future<void> _recordPersonSwipe(String otherUserId, bool liked) async {
    if (_userId == null) return;
    try {
      await _supabase.from('swipes').insert({
        'swiper_id': _userId,
        'swiped_id': otherUserId,
        'direction': liked ? 'like' : 'pass',
      });

      if (liked) {
        // Check for mutual like -> create match
        try {
          final mutual = await _supabase
              .from('swipes')
              .select('id')
              .eq('swiper_id', otherUserId)
              .eq('swiped_id', _userId!)
              .eq('direction', 'like')
              .maybeSingle();
          if (mutual != null) {
            final journeymanId =
                _userRole == 'journeyman' ? _userId : otherUserId;
            final helperId =
                _userRole == 'journeyman' ? otherUserId : _userId;
            try {
              await _supabase.from('matches').insert({
                'journeyman_id': journeymanId,
                'helper_id': helperId,
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('It\'s a match!'),
                    backgroundColor: Color(0xFF22c55e),
                  ),
                );
              }
            } catch (_) {}
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error recording swipe: $e');
    }
  }

  Future<void> _recordJobSwipe(String jobId, bool liked) async {
    if (_userId == null) return;
    try {
      await _supabase.from('job_swipes').insert({
        'user_id': _userId,
        'job_id': jobId,
        'liked': liked,
      });
    } catch (e) {
      debugPrint('Error recording job swipe: $e');
    }
  }

  void _onSwipeEnd(int previousIndex, int targetIndex, SwiperActivity activity) {
    if (activity is! Swipe) return;
    if (previousIndex < 0 || previousIndex >= _cards.length) return;
    final card = _cards[previousIndex];
    final isRight = activity.direction == AxisDirection.right;

    if (widget.mode == 'people') {
      final otherUser = card['user'] as Map<String, dynamic>;
      _recordPersonSwipe(otherUser['id'] as String, isRight);
    } else {
      _recordJobSwipe(card['id'].toString(), isRight);
    }
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        double tempRadius = _radiusKm;
        String tempExp = _experienceFilter;
        String tempTrade = _tradeFilter;
        return StatefulBuilder(builder: (ctx, setS) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Icon(Icons.tune, color: Color(0xFFFF6B35)),
                const SizedBox(width: 8),
                const Text('FILTERS',
                    style: TextStyle(
                        color: Color(0xFFF0F4FF),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2)),
                const Spacer(),
                IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: Color(0xFF8896b0))),
              ]),
              const SizedBox(height: 16),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text('RADIUS: ${tempRadius.round()} KM',
                      style: const TextStyle(
                          color: Color(0xFF8896b0),
                          fontSize: 11,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700))),
              Slider(
                value: tempRadius,
                min: 10,
                max: 500,
                divisions: 49,
                activeColor: const Color(0xFFFF6B35),
                inactiveColor: const Color(0xFF1e2d45),
                label: '${tempRadius.round()} km',
                onChanged: (v) => setS(() => tempRadius = v),
              ),
              const SizedBox(height: 8),
              const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('EXPERIENCE LEVEL',
                      style: TextStyle(
                          color: Color(0xFF8896b0),
                          fontSize: 11,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700))),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                    color: const Color(0xFF0A0E1A),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF1e2d45))),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: tempExp,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF111827),
                    style: const TextStyle(color: Color(0xFFF0F4FF)),
                    items: CrewConstants.experienceFilterLabels
                        .map((l) =>
                            DropdownMenuItem(value: l, child: Text(l)))
                        .toList(),
                    onChanged: (v) => setS(() => tempExp = v ?? 'All'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('TRADE TYPE',
                      style: TextStyle(
                          color: Color(0xFF8896b0),
                          fontSize: 11,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700))),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                    color: const Color(0xFF0A0E1A),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF1e2d45))),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: tempTrade,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF111827),
                    style: const TextStyle(color: Color(0xFFF0F4FF)),
                    items: CrewConstants.tradeFilterLabels
                        .map((l) =>
                            DropdownMenuItem(value: l, child: Text(l)))
                        .toList(),
                    onChanged: (v) => setS(() => tempTrade = v ?? 'All'),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _radiusKm = tempRadius;
                      _experienceFilter = tempExp;
                      _tradeFilter = tempTrade;
                    });
                    Navigator.pop(ctx);
                    _loadCards();
                  },
                  child: const Text('APPLY FILTERS'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setS(() {
                    tempRadius = 100;
                    tempExp = 'All';
                    tempTrade = 'All';
                  });
                },
                child: const Text('RESET',
                    style: TextStyle(color: Color(0xFF8896b0))),
              ),
            ]),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.mode == 'people' ? 'DISCOVER' : 'JOBS';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Color(0xFFFF6B35)),
            onPressed: _showFilters,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF8896b0)),
            onPressed: _loadCards,
          ),
        ],
      ),
      body: _loading || _gettingLocation
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
          : _cards.isEmpty
              ? _buildEmpty()
              : _buildSwiper(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(widget.mode == 'people' ? '👥' : '🔨',
              style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
              widget.mode == 'people'
                  ? 'No one to swipe right now'
                  : 'No jobs to swipe right now',
              style: const TextStyle(
                  color: Color(0xFFF0F4FF),
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Try widening your filters or check back later',
              style: TextStyle(color: Color(0xFF8896b0)),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showFilters,
            icon: const Icon(Icons.tune, size: 18),
            label: const Text('ADJUST FILTERS'),
          ),
        ],
      ),
    );
  }

  Widget _buildSwiper() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              _filterChip(Icons.location_on, '${_radiusKm.round()} km'),
              const SizedBox(width: 6),
              if (_experienceFilter != 'All')
                _filterChip(Icons.work, _experienceFilter),
              if (_experienceFilter != 'All') const SizedBox(width: 6),
              if (_tradeFilter != 'All')
                _filterChip(Icons.build, _tradeFilter),
              const Spacer(),
              Text('${_cards.length}',
                  style: const TextStyle(
                      color: Color(0xFFFF6B35),
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AppinioSwiper(
              controller: _swiperController,
              cardCount: _cards.length,
              swipeOptions: const SwipeOptions.symmetric(horizontal: true),
              onSwipeEnd: _onSwipeEnd,
              onEnd: () {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No more cards! Refreshing...'),
                      backgroundColor: Color(0xFFFF6B35),
                    ),
                  );
                  _loadCards();
                }
              },
              cardBuilder: (context, index) {
                if (widget.mode == 'people') {
                  return _buildPersonCard(_cards[index]);
                }
                return _buildJobCard(_cards[index]);
              },
            ),
          ),
        ),
        _buildActionButtons(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _filterChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1a2235),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF1e2d45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFFF6B35), size: 12),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  color: Color(0xFF8896b0),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildPersonCard(Map<String, dynamic> card) {
    final user = card['user'] as Map<String, dynamic>;
    final profile = card['profile'] as Map<String, dynamic>;
    final distanceKm = card['distance_km'] as double?;
    final name = profile['full_name'] ?? user['email'] ?? 'Unknown';
    final role = user['role'] ?? '';
    final experience = profile['experience_level'] ?? '';
    final tradeType = profile['trade_type'] ?? '';
    final location = profile['location_text'] ?? '';
    final years = profile['years_in_field'] ?? 0;
    final bio = profile['bio'] ?? '';
    final photoUrl = profile['profile_photo_url'];
    final interested = _interestedInMeIds.contains(user['id']);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ViewProfileScreen(
              user: {...user, 'profiles': profile},
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1e2d45), width: 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              Stack(children: [
                SizedBox(
                  width: double.infinity,
                  height: 360,
                  child: photoUrl != null && photoUrl.toString().isNotEmpty
                      ? Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => _placeholderPhoto(),
                          loadingBuilder: (c, child, progress) {
                            if (progress == null) return child;
                            return _placeholderPhoto();
                          },
                        )
                      : _placeholderPhoto(),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 120,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xFF111827)],
                      ),
                    ),
                  ),
                ),
                if (interested)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B35),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                              color:
                                  const Color(0xFFFF6B35).withOpacity(0.5),
                              blurRadius: 8),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.favorite, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text('INTERESTED IN YOU',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5)),
                        ],
                      ),
                    ),
                  ),
                if (distanceKm != null)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on,
                              color: Colors.white, size: 12),
                          const SizedBox(width: 3),
                          Text('${distanceKm.round()} km',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
              ]),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(name,
                                style: const TextStyle(
                                    color: Color(0xFFF0F4FF),
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800),
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (years is int && years > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3A5F),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('${years}y',
                                  style: const TextStyle(
                                      color: Color(0xFF7eb3ff),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          _chip(
                              role.toString().toUpperCase(),
                              role == 'journeyman'
                                  ? const Color(0xFF1E3A5F)
                                  : const Color(0xFFFF6B35).withOpacity(0.2),
                              role == 'journeyman'
                                  ? const Color(0xFF7eb3ff)
                                  : const Color(0xFFFF6B35)),
                          if (experience.toString().isNotEmpty)
                            _chip(
                                CrewConstants.expToLabel(experience),
                                const Color(0xFF1a2235),
                                const Color(0xFF8896b0)),
                          if (tradeType.toString().isNotEmpty)
                            _chip(tradeType, const Color(0xFF1a2235),
                                const Color(0xFF8896b0)),
                        ],
                      ),
                      if (location.toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.location_on,
                              color: Color(0xFF8896b0), size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(location,
                                style: const TextStyle(
                                    color: Color(0xFF8896b0), fontSize: 13),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ]),
                      ],
                      if (bio.toString().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Expanded(
                          child: Text(bio,
                              style: const TextStyle(
                                  color: Color(0xFFF0F4FF),
                                  fontSize: 13,
                                  height: 1.4),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final title = job['title'] ?? 'Untitled Job';
    final description = job['description'] ?? '';
    final location = job['location_text'] ?? '';
    final rate = job['hourly_rate'];
    final duration = job['duration_days'];
    final tradeType = job['trade_type'] ?? '';
    final experience = job['experience_required'] ?? 'any';
    final distanceKm = job['distance_km'] as double?;
    final startDate = job['start_date'];
    final urgentFlag = job['urgent'] == true;

    bool isUrgent = urgentFlag;
    if (!isUrgent && startDate != null) {
      try {
        final dt = DateTime.parse(startDate.toString());
        final daysAway = dt.difference(DateTime.now()).inDays;
        if (daysAway >= 0 && daysAway <= 7) isUrgent = true;
      } catch (_) {}
    }

    final rateValue =
        rate is num ? rate.toDouble() : double.tryParse('$rate') ?? 0;
    final isHighPay = rateValue >= 50;

    String expLabel = experience;
    switch (experience) {
      case 'any':
        expLabel = 'Any Level';
        break;
      case 'apprentice':
        expLabel = 'Apprentice';
        break;
      case 'journeyman':
        expLabel = 'Journeyman';
        break;
      default:
        expLabel = CrewConstants.expToLabel(experience);
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => JobDetailScreen(job: job)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1e2d45), width: 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1E3A5F),
                      const Color(0xFF1E3A5F).withOpacity(0.6),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isUrgent)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFef4444),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                    color: const Color(0xFFef4444)
                                        .withOpacity(0.5),
                                    blurRadius: 6),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bolt,
                                    color: Colors.white, size: 12),
                                SizedBox(width: 3),
                                Text('URGENT',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.5)),
                              ],
                            ),
                          ),
                        if (isHighPay)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF22c55e),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                    color: const Color(0xFF22c55e)
                                        .withOpacity(0.5),
                                    blurRadius: 6),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.attach_money,
                                    color: Colors.white, size: 12),
                                SizedBox(width: 2),
                                Text('HIGH PAY',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.5)),
                              ],
                            ),
                          ),
                        const Spacer(),
                        if (distanceKm != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on,
                                    color: Colors.white, size: 12),
                                const SizedBox(width: 3),
                                Text('${distanceKm.round()} km',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A0E1A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFFF6B35), width: 2),
                          ),
                          child: const Icon(Icons.work,
                              color: Color(0xFFFF6B35), size: 32),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(title,
                              style: const TextStyle(
                                  color: Color(0xFFF0F4FF),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (location.toString().isNotEmpty)
                            _chip('📍 $location',
                                const Color(0xFF1a2235),
                                const Color(0xFF8896b0)),
                          if (rate != null)
                            _chip('\$$rate/hr',
                                const Color(0xFF22c55e).withOpacity(0.15),
                                const Color(0xFF22c55e)),
                          if (duration != null)
                            _chip('$duration days',
                                const Color(0xFF1a2235),
                                const Color(0xFF8896b0)),
                          if (tradeType.toString().isNotEmpty)
                            _chip(tradeType, const Color(0xFF1a2235),
                                const Color(0xFF8896b0)),
                          _chip(expLabel, const Color(0xFF1E3A5F),
                              const Color(0xFF7eb3ff)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(description,
                              style: const TextStyle(
                                  color: Color(0xFFF0F4FF),
                                  fontSize: 13,
                                  height: 1.5)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _circleButton(
            icon: Icons.close,
            color: const Color(0xFFef4444),
            onTap: () {
              if (_cards.isNotEmpty) _swiperController.swipeLeft();
            },
          ),
          _circleButton(
            icon: Icons.refresh,
            color: const Color(0xFF7eb3ff),
            small: true,
            onTap: () {
              try {
                _swiperController.unswipe();
              } catch (_) {}
            },
          ),
          _circleButton(
            icon: Icons.favorite,
            color: const Color(0xFF22c55e),
            onTap: () {
              if (_cards.isNotEmpty) _swiperController.swipeRight();
            },
          ),
        ],
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool small = false,
  }) {
    final size = small ? 48.0 : 60.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Icon(icon, color: color, size: small ? 22 : 28),
      ),
    );
  }

  Widget _placeholderPhoto() {
    return Container(
      color: const Color(0xFF1E3A5F),
      child: const Center(
        child: Icon(Icons.person, color: Color(0xFFFF6B35), size: 96),
      ),
    );
  }

  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label,
          style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5)),
    );
  }
}

