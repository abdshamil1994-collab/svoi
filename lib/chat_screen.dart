import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'feed_screen.dart' show timeAgo;
import 'notifications.dart';
import 'presence.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    this.peerAvatar,
  });

  final String peerId;
  final String peerName;
  final String? peerAvatar;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputController = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  RealtimeChannel? _channel;
  RealtimeChannel? _typingChannel;
  Timer? _pollTimer;
  Timer? _presenceTimer;
  Timer? _typingHideTimer;
  DateTime? _peerLastSeen;
  bool _peerTyping = false;
  DateTime _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);

  SupabaseClient get _client => Supabase.instance.client;
  String get _uid => _client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
    _subscribeTyping();
    _loadPeerPresence();
    // Фолбэк, если realtime нестабилен: опрос каждые 3 секунды.
    _pollTimer = Timer.periodic(
        const Duration(seconds: 3), (_) => _pollNewMessages());
    _presenceTimer = Timer.periodic(
        const Duration(seconds: 15), (_) => _loadPeerPresence());
  }

  @override
  void dispose() {
    _inputController.dispose();
    _pollTimer?.cancel();
    _presenceTimer?.cancel();
    _typingHideTimer?.cancel();
    if (_channel != null) _client.removeChannel(_channel!);
    if (_typingChannel != null) _client.removeChannel(_typingChannel!);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _client
          .from('messages')
          .select('id, sender_id, text, read, created_at')
          .or('and(sender_id.eq.$_uid,receiver_id.eq.${widget.peerId}),'
              'and(sender_id.eq.${widget.peerId},receiver_id.eq.$_uid)')
          .order('created_at');
      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
        _markRead();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pollNewMessages() async {
    try {
      final data = await _client
          .from('messages')
          .select('id, sender_id, text, read, created_at')
          .or('and(sender_id.eq.$_uid,receiver_id.eq.${widget.peerId}),'
              'and(sender_id.eq.${widget.peerId},receiver_id.eq.$_uid)')
          .order('created_at');
      if (!mounted) return;
      final fresh = List<Map<String, dynamic>>.from(data);
      if (fresh.length != _messages.length ||
          (fresh.isNotEmpty &&
              _messages.isNotEmpty &&
              fresh.last['id'] != _messages.last['id']) ||
          fresh.any((m) =>
              m['sender_id'] == _uid &&
              m['read'] !=
                  _messages.firstWhere((x) => x['id'] == m['id'],
                      orElse: () => const {})['read'])) {
        setState(() => _messages = fresh);
        _markRead();
      }
    } catch (_) {}
  }

  Future<void> _markRead() async {
    try {
      await _client
          .from('messages')
          .update({'read': true})
          .eq('sender_id', widget.peerId)
          .eq('receiver_id', _uid)
          .eq('read', false);
    } catch (_) {}
  }

  Future<void> _loadPeerPresence() async {
    try {
      final row = await _client
          .from('profiles')
          .select('last_seen')
          .eq('id', widget.peerId)
          .maybeSingle();
      if (mounted) {
        setState(() => _peerLastSeen =
            DateTime.tryParse(row?['last_seen'] as String? ?? ''));
      }
    } catch (_) {}
  }

  void _subscribe() {
    _channel = _client
        .channel('chat_${widget.peerId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final row = payload.newRecord;
            final pair = {row['sender_id'], row['receiver_id']};
            if (pair.contains(_uid) && pair.contains(widget.peerId)) {
              if (mounted) {
                setState(() {
                  if (!_messages.any((m) => m['id'] == row['id'])) {
                    _messages.add(Map<String, dynamic>.from(row));
                  }
                });
                _markRead();
              }
            }
          },
        )
        .subscribe();
  }

  void _subscribeTyping() {
    final ids = [_uid, widget.peerId]..sort();
    _typingChannel = _client
        .channel('typing_${ids.join('_')}')
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            if (payload['user_id'] == widget.peerId && mounted) {
              setState(() => _peerTyping = true);
              _typingHideTimer?.cancel();
              _typingHideTimer = Timer(const Duration(seconds: 3), () {
                if (mounted) setState(() => _peerTyping = false);
              });
            }
          },
        )
        .subscribe();
  }

  void _onTextChanged(String _) {
    final now = DateTime.now();
    if (now.difference(_lastTypingSent).inSeconds < 2) return;
    _lastTypingSent = now;
    try {
      _typingChannel?.sendBroadcastMessage(
        event: 'typing',
        payload: {'user_id': _uid},
      );
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final row = await _client
          .from('messages')
          .insert({
            'sender_id': _uid,
            'receiver_id': widget.peerId,
            'text': text,
          })
          .select('id, sender_id, text, read, created_at')
          .single();
      sendNotification(userId: widget.peerId, type: 'message');
      if (mounted) {
        _inputController.clear();
        setState(() {
          if (!_messages.any((m) => m['id'] == row['id'])) {
            _messages.add(Map<String, dynamic>.from(row));
          }
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось отправить сообщение')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5);
    final peerOnline = isOnline(_peerLastSeen);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.coral.withValues(alpha: 0.12),
              backgroundImage: widget.peerAvatar != null
                  ? NetworkImage(widget.peerAvatar!)
                  : null,
              child: widget.peerAvatar == null
                  ? const Icon(Icons.person_outline,
                      size: 16, color: AppColors.coral)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.peerName,
                      style: const TextStyle(fontSize: 16),
                      overflow: TextOverflow.ellipsis),
                  Text(
                    _peerTyping
                        ? 'пишет...'
                        : presenceText(_peerLastSeen),
                    style: TextStyle(
                      fontSize: 12,
                      color: _peerTyping
                          ? AppColors.coral
                          : (peerOnline ? Colors.green : muted),
                    ),
                  ),
                ],
              ),
            ),
            if (peerOnline && !_peerTyping)
              const CircleAvatar(radius: 4, backgroundColor: Colors.green),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Text('Начните переписку',
                            style: TextStyle(color: muted)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final m = _messages[i];
                          final mine = m['sender_id'] == _uid;
                          final time = DateTime.tryParse(
                              m['created_at'] as String? ?? '');
                          final read = m['read'] == true;
                          return Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 9),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.72,
                              ),
                              decoration: BoxDecoration(
                                color: mine
                                    ? AppColors.coral
                                    : (isDark
                                        ? AppColors.darkField
                                        : AppColors.lightField),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(mine ? 16 : 4),
                                  bottomRight: Radius.circular(mine ? 4 : 16),
                                ),
                                border: mine
                                    ? null
                                    : Border.all(
                                        color: isDark
                                            ? AppColors.darkBorder
                                            : AppColors.lightBorder,
                                      ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    m['text'] as String? ?? '',
                                    style: TextStyle(
                                      color: mine ? Colors.white : null,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (time != null)
                                        Text(
                                          timeAgo(time),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: mine
                                                ? Colors.white70
                                                : muted,
                                          ),
                                        ),
                                      if (mine) ...[
                                        const SizedBox(width: 4),
                                        Text(
                                          read
                                              ? '✓✓'
                                              : (peerOnline ? '✓✓' : '✓'),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: read
                                                ? Colors.white
                                                : (peerOnline
                                                    ? Colors.white70
                                                    : Colors.white54),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration:
                          const InputDecoration(hintText: 'Сообщение...'),
                      onChanged: _onTextChanged,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.coral,
                            ),
                          )
                        : const Icon(Icons.send, color: AppColors.coral),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
