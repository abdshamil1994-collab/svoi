import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'chat_screen.dart';
import 'feed_screen.dart' show timeAgo;
import 'presence.dart';

/// Общий счётчик непрочитанных сообщений — показывается бейджем
/// на вкладке «Сообщения» в нижней навигации.
final ValueNotifier<int> messagesUnread = ValueNotifier(0);

/// Фоновая служба бейджа непрочитанных: realtime-подписка на входящие
/// + периодический пересчёт. Запускается один раз при старте приложения.
class MessagesBadgeService {
  MessagesBadgeService._();

  static final MessagesBadgeService instance = MessagesBadgeService._();
  // ignore: unused_field — канал живёт всё время работы приложения.
  RealtimeChannel? _channel;
  // ignore: unused_field — таймер живёт всё время работы приложения.
  Timer? _timer;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    refresh();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) return;
      _channel = client
          .channel('messages_badge')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'receiver_id',
              value: uid,
            ),
            callback: (_) => refresh(),
          )
          .subscribe();
    } catch (_) {}
  }

  Future<void> refresh() async {
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) return;
      final res = await client
          .from('messages')
          .select('id')
          .eq('receiver_id', uid)
          .eq('read', false)
          .count(CountOption.exact);
      messagesUnread.value = res.count;
    } catch (_) {}
  }
}

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Map<String, dynamic>>? _dialogs;
  bool _failed = false;
  RealtimeChannel? _channel;
  Timer? _pollTimer;

  SupabaseClient get _client => Supabase.instance.client;
  String get _uid => _client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
    // Фолбэк: опрос каждые 3 секунды, пока экран открыт.
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _load());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    if (_channel != null) _client.removeChannel(_channel!);
    super.dispose();
  }

  void _subscribe() {
    _channel = _client
        .channel('dialogs_$_uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: _uid,
          ),
          callback: (_) => _load(),
        )
        .subscribe();
  }

  Future<void> _load() async {
    try {
      final rows = await _client
          .from('messages')
          .select('id, sender_id, receiver_id, text, read, created_at')
          .or('sender_id.eq.$_uid,receiver_id.eq.$_uid')
          .order('created_at', ascending: false)
          .limit(200);

      // Группируем по собеседнику: последнее сообщение + непрочитанные.
      final byPeer = <String, Map<String, dynamic>>{};
      for (final row in rows as List) {
        final map = Map<String, dynamic>.from(row as Map);
        final peer = map['sender_id'] == _uid
            ? map['receiver_id'] as String
            : map['sender_id'] as String;
        final existing = byPeer[peer];
        if (existing == null) {
          byPeer[peer] = {
            'peer_id': peer,
            'last_text': map['text'],
            'last_time': map['created_at'],
            'unread': 0,
          };
        }
        if (map['receiver_id'] == _uid && map['read'] == false) {
          byPeer[peer]!['unread'] = (byPeer[peer]!['unread'] as int) + 1;
        }
      }

      if (byPeer.isNotEmpty) {
        final profiles = await _client
            .from('profiles')
            .select('id, username, avatar_url, last_seen')
            .inFilter('id', byPeer.keys.toList());
        for (final p in profiles as List) {
          final entry = byPeer[p['id']];
          if (entry != null) {
            entry['username'] = p['username'];
            entry['avatar_url'] = p['avatar_url'];
            entry['last_seen'] = p['last_seen'];
          }
        }
      }

      if (mounted) {
        setState(() {
          _dialogs = byPeer.values.toList()
            ..sort((a, b) => (b['last_time'] as String)
                .compareTo(a['last_time'] as String));
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted && _dialogs == null) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.55);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Сообщения'),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: _buildBody(muted),
    );
  }

  Widget _buildBody(Color? muted) {
    if (_failed && _dialogs == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Не удалось загрузить диалоги',
                style: TextStyle(color: muted)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                setState(() => _failed = false);
                _load();
              },
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }
    final dialogs = _dialogs;
    if (dialogs == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (dialogs.isEmpty) {
      return Center(
        child: Text(
          'Диалогов пока нет.\nНапишите другу со страницы его профиля',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: dialogs.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final d = dialogs[i];
          final avatarUrl = d['avatar_url'] as String?;
          final time = DateTime.tryParse(d['last_time'] as String? ?? '');
          final unread = d['unread'] as int;
          final online =
              isOnline(DateTime.tryParse(d['last_seen'] as String? ?? ''));

          return ListTile(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    peerId: d['peer_id'] as String,
                    peerName: d['username'] as String? ?? 'без имени',
                    peerAvatar: avatarUrl,
                  ),
                ),
              );
              _load();
              MessagesBadgeService.instance.refresh();
            },
            leading: Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.coral.withValues(alpha: 0.12),
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? const Icon(Icons.person_outline, color: AppColors.coral)
                      : null,
                ),
                if (online)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              d['username'] as String? ?? 'без имени',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              online ? 'в сети' : (d['last_text'] as String? ?? ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: online ? const TextStyle(color: Colors.green) : null,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (time != null)
                  Text(timeAgo(time),
                      style: TextStyle(fontSize: 12, color: muted)),
                if (unread > 0) ...[
                  const SizedBox(height: 4),
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: AppColors.coral,
                    child: Text(
                      '$unread',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
