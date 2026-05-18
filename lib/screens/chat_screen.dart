import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  bool _otherTyping = false;
  String? _userId;
  final _random = Random();

  final List<String> _journeymanResponses = [
    "Yeah bud, we got a big job coming up on the pipeline near Rocky. You available next week?",
    "How many years you got under your belt? We need someone who can run a bead clean first try.",
    "Pay's good eh, 45 an hour plus LOA. Camp's not bad either, got wifi and decent grub.",
    "Can you run 7018? That's mostly what we're burning out here on structural.",
    "Last helper I had was greener than grass. You got your CSTS and H2S?",
    "We're doing a turnaround up at Suncor next month. 14 and 7 rotation. You interested?",
    "Bring your own bucket and lid. We supply the rod and wire though.",
    "You comfortable working at heights? We got some pipe rack work coming up.",
    "If you can stick it out for the whole shutdown we'll get you on the rehire list no problem.",
    "I'll send you the safety paperwork tonight. Fill it out and we can get you mobilized by Monday.",
    "Had a guy quit on me yesterday so I need someone ASAP. You good to fly up to Fort Mac?",
    "We're union job so you'll need your UA card. You got that sorted?",
    "The super's pretty chill as long as you show up on time and don't burn holes in everything eh.",
    "What kinda rig you running? MIG or stick? We got both going on this project.",
    "Tell you what, do a good job on this one and I'll keep you busy all winter.",
  ];

  final List<String> _helperResponses = [
    "For sure bud, I'm available right now actually. Just finished up a job in Edson.",
    "Yeah I got my CSTS, H2S, confined space, and fall pro all current. Can send you copies tonight.",
    "I've been welding about 3 years now. Second year apprentice, mostly pipeline and structural.",
    "That sounds awesome man. What's the camp situation like? And is it drive in drive out or fly?",
    "I can run 7018, 6010, and flux core no problem. Still working on my TIG but getting there.",
    "45 an hour? Yeah I'm definitely interested. When do you need me to start?",
    "I got my own tools and PPE. Just need to know what boots you want, steel toe or composite?",
    "I'm a hard worker eh. Last journeyman I worked for said I was the best helper he's had in years.",
    "Can you send me the job scope? I wanna make sure I'm prepped and ready to go day one.",
    "I'm in Red Deer right now but I can be up there in a few hours no problem.",
    "Do I need to bring my own stinger and leads or is that supplied on site?",
    "Sounds like a wicked opportunity. I'm trying to get my hours for my journeyman ticket.",
    "I don't mind working OT either. More hours the better as far as I'm concerned.",
    "My last job was doing B-pressure pipe at the Pembina gas plant. Good reference if you need one.",
    "Just let me know what paperwork you need and I'll get it sorted ASAP.",
  ];

  final List<String> _journeymanGreetings = [
    "Hey there! Saw your profile, looks like you got some decent experience. We're looking for a helper on a job up near Drayton Valley. Interested?",
    "What's going on bud. You looking for work right now? Got a spot that needs filling pretty quick.",
    "Hey! Good to connect. I got a pipeline tie-in job starting next week, could use an extra set of hands.",
  ];

  final List<String> _helperGreetings = [
    "Hey! Thanks for matching. I saw you got some jobs posted, I'm definitely interested in hearing more about them.",
    "What's up man! I'm looking for steady work right now. What kinda projects you got going on?",
    "Hey there! Really looking to get on with a good crew. What's the work situation looking like?",
  ];

  int _responseIndex = 0;
  int _myMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _userId = Supabase.instance.client.auth.currentUser?.id;
    _responseIndex = _random.nextInt(5);
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);

    try {
      final res = await Supabase.instance.client
          .from('messages')
          .select()
          .eq('match_id', widget.matchId)
          .order('sent_at', ascending: true);

      setState(() {
        _messages = (res as List).cast<Map<String, dynamic>>();
        _myMessageCount = _messages.where((m) => m['sender_id'] == _userId).length;
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

  String _getAutoResponse() {
    if (widget.otherUserRole == 'journeyman') {
      if (_myMessageCount <= 1) {
        return _journeymanGreetings[_random.nextInt(_journeymanGreetings.length)];
      }
      final response = _journeymanResponses[_responseIndex % _journeymanResponses.length];
      _responseIndex++;
      return response;
    } else {
      if (_myMessageCount <= 1) {
        return _helperGreetings[_random.nextInt(_helperGreetings.length)];
      }
      final response = _helperResponses[_responseIndex % _helperResponses.length];
      _responseIndex++;
      return response;
    }
  }

  void _doAutoResponse() {
    // Step 1: Show typing indicator immediately
    if (!mounted) return;
    setState(() => _otherTyping = true);
    _scrollToBottom();

    // Step 2: After 800ms, show the response
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;

      final responseText = _getAutoResponse();
      final fakeSenderId = 'auto_${widget.matchId.substring(0, 8)}';

      setState(() {
        _otherTyping = false;
        _messages.add({
          'id': 'auto_${DateTime.now().millisecondsSinceEpoch}',
          'match_id': widget.matchId,
          'sender_id': fakeSenderId,
          'content': responseText,
          'sent_at': DateTime.now().toUtc().toIso8601String(),
          'read_at': null,
        });
      });
      _scrollToBottom();
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _userId == null) return;

    _messageController.clear();
    _myMessageCount++;

    // Add my message to UI immediately
    setState(() {
      _messages.add({
        'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
        'match_id': widget.matchId,
        'sender_id': _userId,
        'content': text,
        'sent_at': DateTime.now().toUtc().toIso8601String(),
        'read_at': null,
      });
    });
    _scrollToBottom();

    // Save to database (fire and forget)
    Supabase.instance.client.from('messages').insert({
      'match_id': widget.matchId,
      'sender_id': _userId,
      'content': text,
    }).then((_) {}).catchError((e) {
      debugPrint('Error saving message: $e');
    });

    // Trigger auto response
    _doAutoResponse();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFF6B35), width: 1.5),
              ),
              child: const Icon(Icons.person, color: Color(0xFFFF6B35), size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _otherTyping ? 'typing...' : widget.otherUserRole.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      color: _otherTyping ? const Color(0xFF22c55e) : const Color(0xFF8896b0),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
                  )
                : _messages.isEmpty
                    ? _buildEmptyChat()
                    : _buildMessageList(),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('💬', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          const Text(
            'No messages yet',
            style: TextStyle(
              color: Color(0xFFF0F4FF),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Say hello to ${widget.otherUserName}!',
            style: const TextStyle(color: Color(0xFF8896b0)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length + (_otherTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (_otherTyping && index == _messages.length) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFF6B35), width: 1.5),
                  ),
                  child: const Icon(Icons.person, color: Color(0xFFFF6B35), size: 16),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1e2d45)),
                  ),
                  child: const Text(
                    '• • •',
                    style: TextStyle(color: Color(0xFF8896b0), fontSize: 16, letterSpacing: 2),
                  ),
                ),
              ],
            ),
          );
        }

        final message = _messages[index];
        final isMe = message['sender_id'] == _userId;
        final content = message['content'] ?? '';
        final sentAt = message['sent_at'] ?? '';

        String timeLabel = '';
        try {
          final dt = DateTime.parse(sentAt).toLocal();
          final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
          final amPm = dt.hour >= 12 ? 'PM' : 'AM';
          final minute = dt.minute.toString().padLeft(2, '0');
          timeLabel = '$hour:$minute $amPm';
        } catch (e) {
          timeLabel = '';
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFF6B35), width: 1.5),
                  ),
                  child: const Icon(Icons.person, color: Color(0xFFFF6B35), size: 16),
                ),
              if (!isMe) const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe
                            ? const Color(0xFFFF6B35)
                            : const Color(0xFF111827),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: isMe
                              ? const Radius.circular(16)
                              : const Radius.circular(4),
                          bottomRight: isMe
                              ? const Radius.circular(4)
                              : const Radius.circular(16),
                        ),
                        border: isMe
                            ? null
                            : Border.all(color: const Color(0xFF1e2d45)),
                      ),
                      child: Text(
                        content,
                        style: TextStyle(
                          color: isMe ? Colors.white : const Color(0xFFF0F4FF),
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ),
                    if (timeLabel.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          timeLabel,
                          style: const TextStyle(
                            color: Color(0xFF8896b0),
                            fontSize: 10,
                          ),
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
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        border: Border(
          top: BorderSide(color: Color(0xFF1e2d45), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0A0E1A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF1e2d45)),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Color(0xFFF0F4FF), fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Color(0xFF8896b0)),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  filled: false,
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
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFFF6B35),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}