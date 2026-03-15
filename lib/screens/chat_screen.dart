import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'view_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final String matchId;
  final String otherUserName;
  final String otherUserRole;

  const ChatScreen({
    super.key,
    required this.matchId,
    required this.otherUserName,
    this.otherUserRole = 'journeyman',
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String? _userId;
  Map<String, dynamic>? _otherUser;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _userId = Supabase.instance.client.auth.currentUser?.id;
    _loadMessages();
    _loadOtherUser();
    _subscribeToMessages();
  }

  void _subscribeToMessages() {
    // Listen for new messages in this match using Supabase Realtime
    final channel = Supabase.instance.client.channel('chat_${widget.matchId}');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'chat_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'match_id',
        value: widget.matchId,
      ),
      callback: (payload) {
        final newMsg = payload.newRecord;
        if (newMsg.isEmpty) return;

        // Don't duplicate messages we sent ourselves (already added optimistically)
        if (newMsg['sender_id'] == _userId) return;

        if (mounted) {
          setState(() {
            // Check if message already exists (by id)
            final exists = _messages.any((m) => m['id'] == newMsg['id']);
            if (!exists) {
              _messages.add(Map<String, dynamic>.from(newMsg));
            }
          });
          _scrollToBottom();
        }
      },
    ).subscribe();
  }

  Future<void> _loadOtherUser() async {
    try {
      final matchRes = await Supabase.instance.client
          .from('matches')
          .select('journeyman_id, helper_id')
          .eq('id', widget.matchId)
          .maybeSingle();

      if (matchRes == null) return;

      final otherId = matchRes['journeyman_id'] == _userId
          ? matchRes['helper_id']
          : matchRes['journeyman_id'];

      // Split query to avoid nested join RLS issues
      final userRes = await Supabase.instance.client
          .from('users')
          .select('id, email, role')
          .eq('id', otherId)
          .maybeSingle();

      if (userRes == null) return;

      final profileRes = await Supabase.instance.client
          .from('profiles')
          .select('full_name, location_text, experience_level, bio, phone, trade_type, years_in_field')
          .eq('user_id', otherId)
          .maybeSingle();

      final combined = Map<String, dynamic>.from(userRes);
      combined['profiles'] = profileRes;

      if (mounted) setState(() => _otherUser = combined);
    } catch (e) {
      debugPrint('Error loading other user: $e');
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client
          .from('chat_messages')
          .select()
          .eq('match_id', widget.matchId)
          .order('sent_at', ascending: true);

      setState(() {
        _messages = (res as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error loading messages: $e');
      setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _userId == null) return;

    _messageController.clear();

    // Optimistic UI — show message immediately
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _messages.add({
        'id': tempId,
        'match_id': widget.matchId,
        'sender_id': _userId,
        'content': text,
        'sent_at': DateTime.now().toUtc().toIso8601String(),
        'read_at': null,
      });
    });
    _scrollToBottom();

    try {
      final res = await Supabase.instance.client.from('chat_messages').insert({
        'match_id': widget.matchId,
        'sender_id': _userId,
        'content': text,
      }).select().single();

      // Replace temp message with real one
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m['id'] == tempId);
          if (idx != -1) _messages[idx] = res;
        });
      }
    } catch (e) {
      debugPrint('Error saving message: $e');
      // Mark as failed
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m['id'] == tempId);
          if (idx != -1) _messages[idx]['failed'] = true;
        });
      }
    }
  }

  void _openOtherProfile() {
    if (_otherUser == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => ViewProfileScreen(user: _otherUser!, matchId: widget.matchId),
    ));
  }

  @override
  void dispose() {
    _subscription?.cancel();
    Supabase.instance.client.removeChannel(
      Supabase.instance.client.channel('chat_${widget.matchId}'),
    );
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _openOtherProfile,
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: const Color(0xFF1E3A5F), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFF6B35), width: 1.5)),
              child: const Icon(Icons.person, color: Color(0xFFFF6B35), size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.otherUserName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Text('Tap to view profile', style: TextStyle(fontSize: 11, color: Color(0xFF8896b0))),
            ])),
          ]),
        ),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
              : _messages.isEmpty ? _buildEmptyChat() : _buildMessageList(),
        ),
        _buildInputBar(),
      ]),
    );
  }

  Widget _buildEmptyChat() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('💬', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 16),
      const Text('No messages yet', style: TextStyle(color: Color(0xFFF0F4FF), fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('Say hello to ${widget.otherUserName}!', style: const TextStyle(color: Color(0xFF8896b0))),
    ]));
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message['sender_id'] == _userId;
        final content = message['content'] ?? '';
        final sentAt = message['sent_at'] ?? '';
        final failed = message['failed'] == true;

        String timeLabel = '';
        try {
          final dt = DateTime.parse(sentAt).toLocal();
          final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
          final amPm = dt.hour >= 12 ? 'PM' : 'AM';
          timeLabel = '${hour}:${dt.minute.toString().padLeft(2, '0')} $amPm';
        } catch (e) { timeLabel = ''; }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe) Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: const Color(0xFF1E3A5F), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFF6B35), width: 1.5)),
                child: const Icon(Icons.person, color: Color(0xFFFF6B35), size: 16),
              ),
              if (!isMe) const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe
                            ? (failed ? const Color(0xFFef4444) : const Color(0xFFFF6B35))
                            : const Color(0xFF111827),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                          bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                          bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                        ),
                        border: isMe ? null : Border.all(color: const Color(0xFF1e2d45)),
                      ),
                      child: Text(content, style: TextStyle(color: isMe ? Colors.white : const Color(0xFFF0F4FF), fontSize: 15, height: 1.4)),
                    ),
                    if (timeLabel.isNotEmpty || failed) Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        failed ? 'Failed to send' : timeLabel,
                        style: TextStyle(color: failed ? const Color(0xFFef4444) : const Color(0xFF8896b0), fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
              if (isMe) const SizedBox(width: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(color: Color(0xFF111827), border: Border(top: BorderSide(color: Color(0xFF1e2d45), width: 1))),
      child: Row(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: const Color(0xFF0A0E1A), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFF1e2d45))),
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'Type a message...', hintStyle: TextStyle(color: Color(0xFF8896b0)),
                border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), filled: false,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _sendMessage,
          child: Container(
            width: 44, height: 44,
            decoration: const BoxDecoration(color: Color(0xFFFF6B35), shape: BoxShape.circle),
            child: const Icon(Icons.send, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }
}
