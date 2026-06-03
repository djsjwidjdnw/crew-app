// Chat screen — real-time 1:1 messaging backed by Supabase Realtime.
//
// Messages live in the "chat_messages" table (already added to the
// "supabase_realtime" publication). We subscribe to a filtered stream so new
// rows inserted by EITHER user appear instantly. Outgoing messages use an
// optimistic-UI pattern: they show immediately as "sending", are awaited into
// the database, then confirmed via the realtime stream (or marked failed/red).
//
// SQL MIGRATION (see supabase_migrations.sql):
//   create table public.chat_messages (
//     id uuid primary key default gen_random_uuid(),
//     match_id uuid references public.matches(id),
//     sender_id uuid references auth.users(id),
//     content text not null,
//     sent_at timestamptz not null default now(),
//     read_at timestamptz
//   );

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../crew_constants.dart';
import '../error_helper.dart';

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
  static const String _table = 'chat_messages';

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  /// Server truth, delivered by the realtime stream (sorted by sent_at asc).
  List<Map<String, dynamic>> _messages = [];

  /// Optimistic messages I've sent that aren't confirmed yet. Each is:
  /// {tempId, content, sent_at, status: 'sending'|'failed'}.
  final List<Map<String, dynamic>> _pending = [];

  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  bool _loading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = Supabase.instance.client.auth.currentUser?.id;
    _subscribe();
  }

  void _subscribe() {
    _sub = Supabase.instance.client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('match_id', widget.matchId)
        .listen(
      (rows) {
        if (!mounted) return;
        final sorted = [...rows]..sort((a, b) => (a['sent_at'] ?? '')
            .toString()
            .compareTo((b['sent_at'] ?? '').toString()));
        setState(() {
          _messages = sorted;
          _loading = false;
        });
        _scrollToBottom();
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() => _loading = false);
        AppFeedback.showError(context, e, fallback: 'Could not load messages');
      },
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
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
    final tempId = 'temp_${DateTime.now().microsecondsSinceEpoch}';
    final pending = <String, dynamic>{
      'tempId': tempId,
      'content': text,
      'sent_at': DateTime.now().toUtc().toIso8601String(),
      'status': 'sending',
    };
    setState(() => _pending.add(pending));
    _scrollToBottom();

    await _insert(pending);
  }

  Future<void> _insert(Map<String, dynamic> pending) async {
    try {
      await Supabase.instance.client.from(_table).insert({
        'match_id': widget.matchId,
        'sender_id': _userId,
        'content': pending['content'],
      });
      if (!mounted) return;
      // Confirmed: the realtime stream now (or imminently) carries the real
      // row, so drop the optimistic placeholder.
      setState(() => _pending.removeWhere((p) => p['tempId'] == pending['tempId']));
    } catch (e) {
      if (!mounted) return;
      setState(() => pending['status'] = 'failed');
      AppFeedback.showError(context, e, fallback: 'Message failed to send');
    }
  }

  Future<void> _retry(Map<String, dynamic> pending) async {
    if (!mounted) return;
    setState(() => pending['status'] = 'sending');
    await _insert(pending);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: CrewConstants.secondary,
                  shape: BoxShape.circle,
                  border: Border.all(color: CrewConstants.primary, width: 1.5),
                ),
                child: const Icon(Icons.person,
                    color: CrewConstants.primary, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.otherUserName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      widget.otherUserRole.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        color: CrewConstants.textSecondary,
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
                      child:
                          CircularProgressIndicator(color: CrewConstants.primary),
                    )
                  : (_messages.isEmpty && _pending.isEmpty)
                      ? _buildEmptyChat()
                      : _buildMessageList(),
            ),
            _buildInputBar(),
          ],
        ),
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
              color: CrewConstants.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Say hello to ${widget.otherUserName}!',
            style: const TextStyle(color: CrewConstants.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    final total = _messages.length + _pending.length;
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: total,
      itemBuilder: (context, index) {
        if (index < _messages.length) {
          final message = _messages[index];
          final isMe = message['sender_id'] == _userId;
          return _bubble(
            content: (message['content'] ?? '').toString(),
            isMe: isMe,
            timeLabel: _timeLabel(message['sent_at']),
            status: null,
          );
        }
        // Optimistic (pending) message — always mine.
        final pending = _pending[index - _messages.length];
        return _bubble(
          content: (pending['content'] ?? '').toString(),
          isMe: true,
          timeLabel: _timeLabel(pending['sent_at']),
          status: pending['status'] as String?,
          onRetry: pending['status'] == 'failed' ? () => _retry(pending) : null,
        );
      },
    );
  }

  String _timeLabel(dynamic sentAt) {
    try {
      final dt = DateTime.parse(sentAt.toString()).toLocal();
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute $amPm';
    } catch (_) {
      return '';
    }
  }

  Widget _bubble({
    required String content,
    required bool isMe,
    required String timeLabel,
    String? status,
    VoidCallback? onRetry,
  }) {
    final failed = status == 'failed';
    final sending = status == 'sending';

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe
            ? (failed ? CrewConstants.danger : CrewConstants.primary)
            : CrewConstants.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft:
              isMe ? const Radius.circular(16) : const Radius.circular(4),
          bottomRight:
              isMe ? const Radius.circular(4) : const Radius.circular(16),
        ),
        border: isMe ? null : Border.all(color: CrewConstants.border),
      ),
      child: Text(
        content,
        style: TextStyle(
          color: isMe ? Colors.white : CrewConstants.textPrimary,
          fontSize: 15,
          height: 1.4,
        ),
      ),
    );

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
                color: CrewConstants.secondary,
                shape: BoxShape.circle,
                border: Border.all(color: CrewConstants.primary, width: 1.5),
              ),
              child: const Icon(Icons.person,
                  color: CrewConstants.primary, size: 16),
            ),
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                bubble,
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (sending) ...[
                        const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: CrewConstants.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('Sending…',
                            style: TextStyle(
                                color: CrewConstants.textSecondary,
                                fontSize: 10)),
                      ] else if (failed) ...[
                        const Icon(Icons.error_outline,
                            color: CrewConstants.danger, size: 12),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: onRetry,
                          child: const Text('Failed — tap to retry',
                              style: TextStyle(
                                  color: CrewConstants.danger,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ] else if (timeLabel.isNotEmpty)
                        Text(
                          timeLabel,
                          style: const TextStyle(
                            color: CrewConstants.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: CrewConstants.surface,
        border: Border(
          top: BorderSide(color: CrewConstants.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: CrewConstants.background,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: CrewConstants.border),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(
                    color: CrewConstants.textPrimary, fontSize: 15),
                maxLength: 2000,
                minLines: 1,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: CrewConstants.textSecondary),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  counterText: '',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                color: CrewConstants.primary,
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
